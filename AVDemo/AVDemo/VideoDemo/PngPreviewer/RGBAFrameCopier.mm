//
//  RGBAFrameCopier.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "RGBAFrameCopier.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import "SCShader.h"
#import "NSString+Path.h"

@implementation RGBAFrameCopier
{
    NSInteger                           frameWidth;
    NSInteger                           frameHeight;
    
    // 着色器程序
    SCShader*                           shader;
    
    // 位置属性
    GLint                               filterPositionAttribute;
    // 纹理坐标属性
    GLint                               filterTextureCoordinateAttribute;
    // 纹理样式属性
    GLint                               filterInputTextureUniform;
    
    // 输入纹理
    GLuint                              _inputTexture;
}

- (BOOL)prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight {
    BOOL ret = NO;
    frameWidth = textureWidth;
    frameHeight = textureHeight;
    
    NSString *vertexPath = [NSString bundlePath:@"PngPreview.vs"];
    NSString *fragmentPath = [NSString bundlePath:@"PngPreview.fs"];
    shader = [[SCShader alloc] initWithVertexPath:vertexPath
                                     fragmentPath:fragmentPath];
    if (shader != nil) { // 着色器程序构建成功
        // 获取着色器中的属性索引
        filterPositionAttribute = [shader getAttribLocation:"position"];
        filterTextureCoordinateAttribute = [shader getAttribLocation:"texcoord"];
        filterInputTextureUniform = [shader getUniformLocation:"inputImageTexture"];
        
        // 在显卡中创建纹理对象（纹理数目, 数组返回地址）
        glGenTextures(1, &_inputTexture);
        // 绑定纹理对象（告诉 OpenGL ES 使用的纹理对象，在解绑之前操作都会针对于该纹理）
        glBindTexture(GL_TEXTURE_2D, _inputTexture);
        // 特定的纹理操作（GL_LINEAR: 双线性过滤，可使用双线性平滑像素之间的过渡）
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // 将该纹理的s轴和t轴的坐标设置为 GL_CLAMP_TO_EDGE 类型，即所有大于1的纹理值至为1，小于0的至为0
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        // 配置绑定了的纹理对象（置空纹理数据）
        glTexImage2D(GL_TEXTURE_2D,        // 纹理类型
                     0,                    // 多级渐远纹理类型
                     GL_RGBA,              // 纹理存储格式
                     (GLsizei)frameWidth,  // 纹理宽度
                     (GLsizei)frameHeight, // 纹理高度
                     0,                    // 历史遗留参数(0即可)
                     GL_RGBA,              // 源图数据格式
                     GL_UNSIGNED_BYTE,     // 源图数据类型
                     0);                   // 源图数据
        // 解绑纹理对象
        glBindTexture(GL_TEXTURE_2D, 0);
        ret = YES;
    }
    return ret;
}

#pragma mark - 绘制部分
- (void)renderFrame:(uint8_t*)rgbaFrame {
    // 使用显卡绘制程序
    [shader useProgram];
    
    // 设置当前缓冲
    // 设置颜色缓缓冲值
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    // 应用当前值清除缓冲区
    // - GL_COLOR_BUFFER_BIT: 颜色缓冲
    // - GL_DEPTH_BUFFER_BIT: 深度缓冲
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // 开启色彩混合
    glEnable(GL_BLEND);
    // 配置色彩混合因子: 源因子为源像素的alpha，目标因子为(1.0-源像素的alpha)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // 配置纹理数据
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    glTexImage2D(GL_TEXTURE_2D,        // 纹理类型
                 0,                    // 多级渐远纹理类型
                 GL_RGBA,              // 纹理存储格式
                 (GLsizei)frameWidth,  // 纹理宽度
                 (GLsizei)frameHeight, // 纹理高度
                 0,                    // 历史遗留参数(0即可)
                 GL_RGBA,              // 源图数据格式
                 GL_UNSIGNED_BYTE,     // 源图数据类型
                 rgbaFrame);           // 源图数据
    glBindTexture(GL_TEXTURE_2D, 0);
    
    // 配置物体坐标，将其加载到GPU中
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f,  -1.0f,
        -1.0f, 1.0f,
        1.0f,  1.0f,
    };
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);

    // 配置纹理坐标，将其加载到GPU中
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);

    // 指定将要绘制的纹理对象并且传递给对应的片元着色器
    // 激活第一层纹理
    glActiveTexture(GL_TEXTURE0);
    // 绑定纹理
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    // 告诉GLSL我们渲染的是第一层纹理（对纹理层和采样器地址进行绑定）
    glUniform1i(filterInputTextureUniform, 0);
    
    // 执行绘制操作
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

// 绘制后的清除逻辑
- (void)releaseRender {
    shader = nil;
    if(_inputTexture) {
        glDeleteTextures(1, &_inputTexture);
    }
}
@end

