//
//  BaseEffectFilter.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ShaderUtils.h"
#import "SCShader.h"

@protocol ImageFilterInput <NSObject>

// 渲染操作
- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position;

// 纹理设置
- (void)setInputTexture:(GLint)textureId;

@end

@interface BaseEffectFilter : NSObject
{
    GLint                               _inputTexId;
    
    GLint                               filterPositionAttribute;
    GLint                               filterTextureCoordinateAttribute;
    GLint                               filterInputTextureUniform;
    
    SCShader*                           shader;
}

// 渲染准备工作
- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight;

// 构建着色器程序
- (BOOL)buildProgram:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader;

// 使用着色器程序
- (BOOL)useProgram;

// 渲染后的释放操作
- (void)releaseRender;

// 获取输出纹理
- (GLint)outputTextureID;

// ImageFilterInput
// 渲染操作
- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position;

// 设置输入纹理
- (void)setInputTexture:(GLint)textureId;

@end
