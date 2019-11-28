//
//  RGBAFrameCopier.m
//  OpenGLRenderer
//
//  Created by SeacenLiu on 2019/11/15.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "RGBAFrameCopier.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#pragma mark - 顶点着色器
NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = position;
     v_texcoord = texcoord.xy;
 }
);

#pragma mark - 片元着色器
NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, v_texcoord);
 }
);

@implementation RGBAFrameCopier
{
    NSInteger                           frameWidth;
    NSInteger                           frameHeight;
    
    // 纹理过滤器程序
    GLuint                              filterProgram;
    GLint                               filterPositionAttribute;
    GLint                               filterTextureCoordinateAttribute;
    GLint                               filterInputTextureUniform;
    
    // 纹理
    GLuint                              _inputTexture;
}
- (BOOL) prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;
{
    BOOL ret = NO;
    frameWidth = textureWidth;
    frameHeight = textureHeight;
    // 构建显卡程序
    if([self buildProgram:vertexShaderString fragmentShader:rgbFragmentShaderString]) {
        // *** 编辑纹理对象 ***
        // 1: 在显卡中创建纹理对象（纹理数目, 数组返回地址）
        glGenTextures(1, &_inputTexture);
        // 2: 绑定纹理对象
        //（告诉 OpenGL ES 使用的纹理对象，在解绑之前操作都会针对于该纹理）
        glBindTexture(GL_TEXTURE_2D, _inputTexture);
        // 3: 特定的纹理操作
        // 3-1: 放大（GL_LINEAR: 双线性过滤，可使用双线性平滑像素之间的过渡）
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        // 3-2: 缩小
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // 3-3: 将该纹理的s轴和t轴的坐标设置为 GL_CLAMP_TO_EDGE 类型，即所有大于1的纹理值至为1，小于0的至为0
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        // 4: 将 PNG 素材的内容放到该纹理对象上
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        // 5: 解绑纹理对象
        glBindTexture(GL_TEXTURE_2D, 0);
        ret = YES;
    }
    return ret;
}

#pragma mark - 创建显卡执行程序
- (BOOL) buildProgram:(NSString*) vertexShader fragmentShader:(NSString*) fragmentShader;
{
    BOOL result = NO;
    // 1: 创建程序实例（纹理过滤器）
    filterProgram = glCreateProgram();
    // 2: 编译着色器
    GLuint vertShader = 0, fragShader = 0;
    // 2-1: 编译顶点着色器
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShader);
    if (!vertShader)
        goto exit;
    // 2-2: 编译片元着色器
    fragShader = compileShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (!fragShader)
        goto exit;
    
    // 3: 将顶点着色器程序附加进目标程序
    glAttachShader(filterProgram, vertShader);
    // 4: 将片元着色器程序附加进目标程序
    glAttachShader(filterProgram, fragShader);
    
    // 5: 连接程序
    glLinkProgram(filterProgram);
    
    // 获取显卡程序中的属性
    filterPositionAttribute = glGetAttribLocation(filterProgram, "position");
    filterTextureCoordinateAttribute = glGetAttribLocation(filterProgram, "texcoord");
    filterInputTextureUniform = glGetUniformLocation(filterProgram, "inputImageTexture");
    
    // 验证显卡程序连接情况
    GLint status;
    glGetProgramiv(filterProgram, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", filterProgram);
        goto exit;
    }
    result = validateProgram(filterProgram);
exit:
    // 清除逻辑
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    return result;
}

#pragma mark - 绘制部分
- (void) renderFrame:(uint8_t*) rgbaFrame;
{
    // 使用显卡绘制程序
    glUseProgram(filterProgram);
    
    glClearColor(0.0f, 0.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, rgbaFrame);
    
    // 设置物体坐标
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    
    // 设置纹理坐标
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    // 指定将要绘制的纹理对象并且传递给对应的片元着色器
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    glUniform1i(filterInputTextureUniform, 0);
    
    // 执行绘制操作
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

// 绘制后的清除逻辑
- (void) releaseRender;
{
    if (filterProgram) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    if(_inputTexture) {
        glDeleteTextures(1, &_inputTexture);
    }
}
@end
