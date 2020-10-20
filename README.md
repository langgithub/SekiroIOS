# SekiroIOS
1. SekiroIOS是与Sekiro服务器通讯工具，完成Sekiro 主动hook命令下发到IOS端
2. 该项目是Sekiro-lib的组件 https://github.com/langgithub/sekiro-lang
3. Sekiro项目目前已完成 Android端 www端 IOS端通讯

# 注意
SekiroNatClient.m中的IP和端口是sekiro 长链接IP和端口，需要自行修改
static  NSString * Khost = @"172.20.20.11";
static const uint16_t Kport = 11000;
