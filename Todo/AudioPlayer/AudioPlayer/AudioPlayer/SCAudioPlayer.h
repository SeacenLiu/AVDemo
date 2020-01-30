//
//  SCAudioPlayer.h
//  AudioPlayer
//
//  Created by SeacenLiu on 2019/11/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCAudioPlayer : NSObject

- (instancetype)initWithFilePath:(NSString*)filePath;

- (void) start;

- (void) stop;

@end
