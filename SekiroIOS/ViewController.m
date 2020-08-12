//
//  ViewController.m
//  SekiroIOS
//
//  Created by yuanlang on 2020/8/12.
//  Copyright © 2020年 yuanlang. All rights reserved.
//

#import "ViewController.h"
#import "SekiroNatClient.h"


@interface ViewController ()

- (IBAction)connection:(id)sender;

@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
}

//连接
- (void)connectAction
{
    BOOL isConnect = [[TYHSocketManager share] connect];
    if (isConnect ) {
        NSLog(@"开始连接...");
    }else{
        NSLog(@"连接失败");
    }
    
}
//断开连接
- (void)disConnectAction
{
    [[TYHSocketManager share] disConnect];
}
- (IBAction)connection:(id)sender {
    NSLog(@"开始连接...");
    [self connectAction];
}
@end
