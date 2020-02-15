//
//  SCShader.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "SCShader.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@implementation SCShader {
    GLuint programID;
}

- (instancetype)initWithVertexPath:(NSString*)vertexPath
                      fragmentPath:(NSString*)fragmentPath {
    NSString *vertexShaderString = [self loadStringWithPath:vertexPath];
    NSString *fragmentShaderString = [self loadStringWithPath:fragmentPath];
    return [self initWithVertexString:vertexShaderString fragmentString:fragmentShaderString];
}

- (instancetype)initWithVertexString:(NSString*)vertexString
                      fragmentString:(NSString*)fragmentString {
    if (self = [super init]) {
        BOOL isSucceed = [self buildProgram:vertexString fragmentShader:fragmentString];
        if (isSucceed == NO) {
            return nil;
        }
    }
    return self;
}

- (GLint)getAttribLocation:(const GLchar*)name {
    return glGetAttribLocation(programID, name);
}

- (GLint)getUniformLocation:(const GLchar*)name {
    return glGetUniformLocation(programID, name);
}

- (void)useProgram {
    glUseProgram(programID);
}

- (GLuint)programID {
    return programID;
}

- (void)dealloc {
    glDeleteProgram(programID);
    programID = 0;
}

#pragma mark - private method
- (BOOL)buildProgram:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader {
    BOOL result = NO;
    // 1: 创建程序实例（纹理过滤器）
    programID = glCreateProgram();
    // 2: 编译着色器
    GLuint vertShader = 0, fragShader = 0;
    // 2-1: 编译顶点着色器
    vertShader = [self compileShader:vertexShader type:GL_VERTEX_SHADER];
    if (!vertShader)
        goto exit;
    // 2-2: 编译片元着色器
    fragShader = [self compileShader:fragmentShader type:GL_FRAGMENT_SHADER];
    if (!fragShader)
        goto exit;
    // 3: 将顶点着色器程序附加进目标程序
    glAttachShader(programID, vertShader);
    // 4: 将片元着色器程序附加进目标程序
    glAttachShader(programID, fragShader);
    // 5: 连接程序
    glLinkProgram(programID);
    // 6: 验证显卡程序连接情况
    GLint status;
    glGetProgramiv(programID, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", programID);
        goto exit;
    }
    result = [self validateProgram:programID];
exit:
    // 7: 清除逻辑
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    // 8: 处理返回
    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(programID);
        programID = 0;
    }
    return result;
}

- (GLuint)compileShader:(NSString*)shaderString type:(GLenum)type {
    GLint status;
    // 1: 创建着色器
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"Failed to create shader %d", type);
        return 0;
    }
    // 2: 加载着色器源码
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    glShaderSource(shader, 1, &sources, NULL);
    // 3: 编译着色器
    glCompileShader(shader);
#ifdef DEBUG
    // 4: 打印编译信息
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    // 5: 验证着色器是否编译成功
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        NSLog(@"Failed to compile shader:\n");
        return 0;
    }
    
    return shader;
}

- (BOOL)validateProgram:(GLuint)program {
    GLint status;
    glValidateProgram(program);
#ifdef DEBUG
    // 打印程序信息
    GLint logLength;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
    // 验证着色器程序是否有效
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to validate program %d", program);
        return NO;
    }
    return YES;
}

- (NSString*)loadStringWithPath:(NSString*)path {
    NSError *error;
    NSString *str = [[NSString alloc] initWithContentsOfFile:path
                                                    encoding:NSUTF8StringEncoding
                                                       error:&error];
    if (error) {
        NSLog(@"load String from File Error: %@", error);
        return @"";
    }
    return str;
}

@end
