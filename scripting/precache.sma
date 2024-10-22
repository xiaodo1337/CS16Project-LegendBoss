#include <amxmodx>

#pragma tabsize 4

public plugin_init()
{
	register_plugin("Custom Precache Resources", "1.0", "xiaodo")
}

public plugin_precache()
{
	new conffile[200], configdir[200];
	get_configsdir(configdir, charsmax(configdir))
	format(conffile, charsmax(conffile), "%s/precache.ini", configdir)
	if (!file_exists(conffile))
    {
    	log_amx("[BM]预缓存配置文件%s不存在！", conffile)
        set_fail_state("预缓存配置文件不存在")
    	return PLUGIN_CONTINUE
    }
    new lines, file[1024], len;
    lines = file_size(conffile, 1)
    for (new i;i < lines;i++)
	{
        read_file(conffile, i, file, charsmax(file), len)
        if (!equal(file, "", 1))
        {
            precache_generic(file)
        }
    }
    return PLUGIN_HANDLED
}

stock get_configsdir(name[], len)
{
	return get_localinfo("amxx_configsdir", name, len)
}