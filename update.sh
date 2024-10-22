NOW_PATH=`pwd`
GIT_BASE_PATH="/cygdrive/d/steam/steamapps/common/Half-Life/cstrike/addons/amxmodx/CS16Project-Legend-Boss"
NEED_CHANGEPATH=0
if [ $NOW_PATH != $GIT_BASE_PATH ]
then
	NEED_CHANGEPATH=1
	cd $GIT_BASE_PATH
fi
cp $(cat ../configs/plugins-boss.ini | grep -Ev '^.$|^;|^//' | sed 's/debug//g;s/.amxx/.sma/g;s/\r//g;' | awk '{print "../scripting/"$1}') ./scripting/
cp $(cat $(cat ../configs/plugins-boss.ini | grep -Ev '^.$|^;|^//' | sed 's/debug//g;s/.amxx/.sma/g;s/\r//g;' | awk '{print "../scripting/"$1}') | grep -E '^#include' | sed 's/#include <//g;s/>//g;s/\r//g' | grep -Ev '^xs$|^fakemeta|amxmodx|^amxmisc$|^cstrike$|^hlsdk_const$|^fun$|^sqlx$|^hamsandwich$|^regex$|^nvault$|engine|^sockets$|^json$' | awk '{print "../scripting/include/"$1".inc"}' | sort | uniq | sed 's/\r//g') ./scripting/include/
cp ../configs/plugins-boss.ini ./configs/
#git add ./
#git commit -m 'Plugins Update'
#git push
if [ $NEED_CHANGEPATH -eq 1 ]
then
	cd - > /dev/null
fi
echo "插件内容已更新"
