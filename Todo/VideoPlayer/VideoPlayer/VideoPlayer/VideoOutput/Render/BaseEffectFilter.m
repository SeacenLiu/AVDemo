//
//  BaseEffectFilter.m
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import "BaseEffectFilter.h"

@implementation BaseEffectFilter

- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight {
    return NO;
}

- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position {
    
}

- (BOOL)buildProgram:(NSString*)vertexShader fragmentShader:(NSString*) fragmentShader {
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

- (void)releaseRender {
    if (filterProgram) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
}

- (void)setInputTexture:(GLint)textureId {
    _inputTexId = textureId;
}

- (GLint)outputTextureID {
    return -1;
}

@end
