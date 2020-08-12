//
//  SekiroNatClient.m
//  SekiroIOS
//
//  Created by yuanlang on 2020/8/12.
//  Copyright © 2020年 yuanlang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SekiroNatClient.h"
#import "GCDAsyncSocket.h" // for TCP

//读者需要修改这个Host,改成电脑（服务端IP地址）
//static  NSString * Khost = @"192.168.0.130";
//static const uint16_t Kport = 6969;
static  NSString * Khost = @"172.20.20.11";
static const uint16_t Kport = 11000;

@interface TYHSocketManager()<GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *gcdSocket;
}
//发送心跳包的线程
@property (nonatomic, strong)NSThread *thread;
@property (strong,nonatomic)NSTimer *timer;
@end


@implementation TYHSocketManager

// 单例
+ (instancetype)share
{
    static dispatch_once_t onceToken;
    static TYHSocketManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
        [instance initSocket];
    });
    return instance;
}
- (void)initSocket
{
    gcdSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}
// 创建线程
- (NSThread*)thread{
    if (!_thread) {
        _thread = [[NSThread alloc]initWithTarget:self selector:@selector(threadStart) object:nil];
    }
    return _thread;
}
//字典转为Json字符串
- (NSString *)dictionaryToJson:(NSDictionary *)dic
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - 对外的一些接口
//建立连接
- (BOOL)connect
{
    BOOL isConnect = [gcdSocket connectToHost:Khost onPort:Kport error:nil];
    if(isConnect){
        // 注册手机
        NSString *prefix =  @"langyuan";
        NSString *ext = [NSString stringWithFormat:@"%@@wx_chat",prefix];
        NSData *cmd = [self makeDataWithExt:ext msg:nil msgType:0x01 serial_number_data:nil];
        [gcdSocket writeData:cmd withTimeout:-1 tag:0];
    }
    return isConnect;
}

//断开连接
- (void)disConnect
{
    [gcdSocket disconnect];
}


#pragma mark - GCDAsyncSocketDelegate
//连接成功调用
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"连接成功,host:%@,port:%d",host,port);
    //开始发送心跳包
    [self.thread start];
    [sock readDataWithTimeout:-1 tag:99];
}

//心跳包发送
- (void)threadStart{
    @autoreleasepool {
        _timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(heartBeat) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop]run];
    }
}
- (void)heartBeat{
    NSData *cmd = [self makeDataWithExt:nil msg:nil msgType:0x07 serial_number_data:nil];
    [gcdSocket writeData:cmd withTimeout:-1 tag:7];
}

// 消息体
- (NSData *)makeDataWithExt:(NSString *)ext msg:(NSString *)dicStr msgType:(int8_t)msgType serial_number_data:(NSData *)serial_number_data{
    
    // 类似于byte数组
    NSData *dext = [ext dataUsingEncoding:NSUTF8StringEncoding];
    // 类似于bytebuffer
    NSMutableData * cmdData = [[NSMutableData alloc] init];
    // 字符串转byte数组
    NSData *cmd = [dicStr dataUsingEncoding:NSUTF8StringEncoding];
    
    // 申请 1 + 8 + 1 + ext实际内容length + dicStr实际内容length
    __int32_t packet_length = sizeof(int8_t) + sizeof(int64_t) + sizeof(int8_t) + (int)[dext length] + (int)cmd.length;
    // 将主机的unsigned long 转为网络字节顺序
    HTONL(packet_length);
    // bytebuffer 填充
    [cmdData appendBytes:&packet_length length:sizeof(__int32_t)];
    //消息类型
    int8_t message_type = msgType;
    [cmdData appendBytes:&message_type length:sizeof(int8_t)];
    //消息id
    if (serial_number_data) {
        [cmdData appendData:serial_number_data];
    } else {
        int64_t serial_number = 0x00;
        [cmdData appendBytes:&serial_number length:sizeof(int64_t)];
    }
    //ext扩展长度
    int8_t ext_length = [dext length];
    [cmdData appendBytes:&ext_length length:sizeof(int8_t)];//no disconnect
    
    [cmdData appendData:dext];
    [cmdData appendData:cmd];
    
    return cmdData;
}

//回写消息
- (void)writeSocketsMsg:(NSString *)msg serial_number_data:(NSData *)serial_number_data{
    NSData *cmd = [self makeDataWithExt:@"application/json;charset=utf-8" msg:msg msgType:0x02 serial_number_data:serial_number_data];
    [gcdSocket writeData:cmd withTimeout:-1 tag:0];
}

//断开连接的时候调用
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err
{
    NSLog(@"断开连接,host:%@,port:%d",sock.localHost,sock.localPort);
    
    //断线重连写在这...
    _timer = nil;
    _thread = nil;
    [self connect];
}


//写的回调
- (void)socket:(GCDAsyncSocket*)sock didWriteDataWithTag:(long)tag
{
    if(tag == 7){
        NSLog(@"发送心跳 heartBeat 成功,tag:%ld",tag);
    }
}


// 获取request -> 返回response
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    // 解包
    int packet_length =  *(int *)([[data subdataWithRange:NSMakeRange(0, 4)] bytes]);
    int message_type =  *(int *)([[data subdataWithRange:NSMakeRange(4, 1)] bytes]);
    int serial_number =  *(int *)([[data subdataWithRange:NSMakeRange(5, 8)] bytes]);
    int ext_length =  *(int *)([[data subdataWithRange:NSMakeRange(13, 1)] bytes]);
    NSString *ext = [[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(14, ext_length)] encoding:NSUTF8StringEncoding];
    int bodyLength = (int)[data length] - 4 - 1 - 8 - 1 - (int)[ext length];
    int bodyStart = 14 + ext_length;
    NSString *payload = [[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(bodyStart, bodyLength)] encoding:NSUTF8StringEncoding];
    NSLog(@"message_type:%d",message_type);
    if(message_type == 2){
        // 打印参数
        NSLog(@"packet_length:%d",packet_length);
        NSLog(@"message_type:%d",message_type);
        NSLog(@"serial_number:%d",serial_number);
        NSLog(@"ext_length:%d",ext_length);
        NSLog(@"ext:%@",ext);
        NSLog(@"payload:%@",payload);
        
        // 回写数据
        NSDictionary *bodyDict = @{@"status":@"0",@"message":@"",@"data":payload};
        NSString *body = [self dictionaryToJson:bodyDict];
        NSData *cmd = [self makeDataWithExt:@"application/json;charset=utf-8" msg:body msgType:0x02 serial_number_data:[data subdataWithRange:NSMakeRange(5, 8)]];
        [sock writeData:cmd withTimeout:-1 tag:0];
    }
    [sock readDataWithTimeout:-1 tag:99];
}
@end
