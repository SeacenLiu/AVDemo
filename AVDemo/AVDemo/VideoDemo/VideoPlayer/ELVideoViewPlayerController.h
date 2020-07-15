//
//  ELVideoViewPlayerController.h
//  video_player
//
//  Created by apple on 16/9/27.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ELVideoViewPlayerController : UIViewController

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                                   parameters:(NSDictionary *)parameters;

@end
