//
//  SCShader.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCShader : NSObject

@property (nonatomic, assign, readonly) GLuint programID;

- (instancetype)initWithVertexPath:(NSString*)vertexPath
                      fragmentPath:(NSString*)fragmentPath;
- (instancetype)initWithVertexString:(NSString*)vertexString
                      fragmentString:(NSString*)fragmentString;

- (void)useProgram;
- (GLint)getAttribLocation:(const GLchar*)name;
- (GLint)getUniformLocation:(const GLchar*)name;

@end
