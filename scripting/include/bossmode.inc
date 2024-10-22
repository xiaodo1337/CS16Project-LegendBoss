enum
{
    TYPE_FREE = 0,
    TYPE_PISTOL,
    TYPE_FOREVER,
    TYPE_SPECIAL,
    TYPE_KNIFE
}

enum
{
	MODE_NORMAL = 0,
	MODE_LEADER,
	MODE_ESCAPE
}

native bm_get_user_hide(id);
native bm_get_user_level(id);
native bm_set_user_level(id, amount);
native bm_get_user_sp(id);
native bm_set_user_sp(id, amount);
native bm_get_user_xp(id);
native bm_set_user_xp(id, amount);

native bm_get_user_boss(id);
native bm_set_user_gash(id, amount);
native bm_get_user_gash(id);
native bm_get_mode();
native bm_add_item(id, itemid, amount);   //带消息提示的增加物品
native bm_add_item2(id, itemid, amount);   //不带消息提示的增加物品
native bm_set_user_weaponid(id, wepid);
native bm_weapon_register(szName[], szSaveName[], iType, WeaponCostSP, WeaponCostGash, WeaponLevel, WeaponBasedOn, const WeaponCommit[] = "");
native bm_get_boss_blood_color();

forward bm_weapon_bought(id, ItemID);
forward bm_weapon_remove(id);
forward bm_user_become_boss(id);
forward bm_user_become_human(id);

stock drop_weapons(iPlayer, Slot)
{
	new item = get_pdata_cbase(iPlayer, 367+Slot, 4)
	while(item > 0 && pev_valid(item))
	{
		static classname[24]
		pev(item, pev_classname, classname, charsmax(classname))
		if(is_user_bot(iPlayer) || Slot == 3)
		{
			ExecuteHamB(Ham_Weapon_RetireWeapon, item)
			ExecuteHamB(Ham_RemovePlayerItem, iPlayer, item)
			ExecuteHamB(Ham_Item_Kill, item)
			set_pev(iPlayer, pev_weapons, pev(iPlayer, pev_weapons) & ~(1<<get_pdata_int(item, 43, 4)))
		}
		else engclient_cmd(iPlayer, "drop", classname)
		item = get_pdata_cbase(item, 42, 5)
	}
	set_pdata_cbase(iPlayer, 367, -1, 4)
}