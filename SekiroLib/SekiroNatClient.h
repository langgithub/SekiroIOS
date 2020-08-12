//
//  SekiroNatClient.h
//  SekiroIOS
//
//  Created by yuanlang on 2020/8/12.
//  Copyright © 2020年 yuanlang. All rights reserved.
//

#ifndef SekiroNatClient_h
#define SekiroNatClient_h

#import <Foundation/Foundation.h>

@interface TYHSocketManager : NSObject

+ (instancetype)share;

- (BOOL)connect;
- (void)disConnect;

@end

#endif /* SekiroNatClient_h */
