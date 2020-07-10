//
//  RGBAFrameCopier.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * RGBA 像素帧渲染器
 * - 将 RGBA 像素数据拷贝到 OpenGL 的纹理上进行展示
 */
@interface RGBAFrameCopier : NSObject

- (BOOL)prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;

- (void)renderFrame:(uint8_t*)rgbaFrame;

- (void)releaseRender;

@end
