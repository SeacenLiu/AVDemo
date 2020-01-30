//
//  AudioRecorder.h
//  AudioRecorder
//
//  Created by SeacenLiu on 2019/12/5.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioRecorder : NSObject

- (instancetype)initWithPath:(NSString*)path;

- (void)start;

- (void)stop;

@end
