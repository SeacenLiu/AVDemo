//
//  RGBAFrameCopier.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RGBAFrameCopier : NSObject

- (BOOL)prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;

- (void)renderFrame:(uint8_t*)rgbaFrame;

- (void)releaseRender;

@end
