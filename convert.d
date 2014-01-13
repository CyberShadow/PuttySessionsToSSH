import std.exception;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.windows.registry;

import ae.sys.clipboard;

void main()
{
	auto k = Registry.currentUser.getKey(`Software\SimonTatham\PuTTY\Sessions`);
	auto config = File("config", "wb");
	scope(failure) { config.close(); "config"[].remove(); }

	foreach (session; k.keys)
	{
		if (session.name == "Default%20Settings")
			continue;

		auto ppk = session.getValue("PublicKeyFile").value_SZ; // lol
		string privateKey;
		if (ppk)
		{
			privateKey = session.name;
			auto publicKey = privateKey ~ ".pub";

			if (!privateKey.exists)
			{
				stderr.writeln("Launching PuTTYGen for key conversion.");
				stderr.writeln("Please go to Conversions -> Export OpenSSH key, and save as");
				stderr.writeln(privateKey.absolutePath);
				stderr.writeln("(copied to clipboard; press Alt+V O Enter Ctrl+V Enter Esc)");
				stderr.writeln("...");
				setClipboardText(privateKey.absolutePath);

				auto status = execute(["puttygen"] ~ ppk).status;
				enforce(status==0, "puttygen failed");

				enforce(privateKey.exists, "Private key not created.");
				stderr.writeln("OK.");
			}

			if (!publicKey.exists)
			{
				auto status = spawnProcess(["ssh-keygen", "-y", "-f", privateKey], stdin, File(publicKey, "wb")).wait;
				enforce(status==0, "ssh-keygen failed");
			}
		}

		config.writeln("Host ", session.name);
		config.writeln("Hostname ", session.getValue("HostName").value_SZ);
		config.writeln("User ", session.getValue("UserName").value_SZ);
		if (privateKey)
			config.writeln("IdentityFile ~/.ssh/", privateKey);
		config.writeln();
	}
}
