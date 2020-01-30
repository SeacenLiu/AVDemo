//
//  GPUTextureFrame.h
//  liveDemo
//
//  Created by apple on 16/3/1.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreGraphics/CGGeometry.h>

typedef struct GPUTextureFrameOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GPUTextureFrameOptions;

/**
 * 画面纹理类
 */
@interface ELImageTextureFrame : NSObject

- (instancetype)initWithSize:(CGSize)framebufferSize;

- (instancetype)initWithSize:(CGSize)framebufferSize textureOptions:(GPUTextureFrameOptions)fboTextureOptions;

- (void)activateFramebuffer;

- (GLuint)texture;

- (GLubyte *)byteBuffer;

- (int)width;
- (int)height;
@end
