//
//  BaseEffectFilter.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ShaderUtils.h"

@protocol ImageFilterInput <NSObject>

// 渲染操作
- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position;

// 纹理设置
- (void)setInputTexture:(GLint)textureId;

@end

@interface BaseEffectFilter : NSObject
{
    GLint                               _inputTexId;
    
    GLuint                              filterProgram;
    GLint                               filterPositionAttribute;
    GLint                               filterTextureCoordinateAttribute;
    GLint                               filterInputTextureUniform;
    
}

// 渲染准备工作
- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight;

// 构建着色器程序
- (BOOL)buildProgram:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader;

// 渲染操作
- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position;

// 渲染后的释放操作
- (void)releaseRender;

// 设置输入纹理
- (void)setInputTexture:(GLint)textureId;

// 获取输出纹理
- (GLint)outputTextureID;

@end
