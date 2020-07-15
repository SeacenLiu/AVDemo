//
//  BaseEffectFilter.m
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import "BaseEffectFilter.h"
#import "SCShader.h"

@interface BaseEffectFilter ()


@end

@implementation BaseEffectFilter

- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight {
    return NO;
}

- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position {
    
}

- (BOOL)buildProgram:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader {
    BOOL result = NO;
    
    shader = [[SCShader alloc] initWithVertexString:vertexShader fragmentString:fragmentShader];
    if (shader != nil) {
//        filterProgram = shader.programID;
        
        // 获取显卡程序中的属性
        filterPositionAttribute = [shader getAttribLocation:"position"];
        filterTextureCoordinateAttribute = [shader getAttribLocation:"texcoord"];
        filterInputTextureUniform = [shader getUniformLocation:"inputImageTexture"];
        
        result = YES;
    }
    
    return result;
}

- (BOOL)useProgram {
    [shader useProgram];
    return YES;
}

- (void)releaseRender {
//    if (filterProgram) {
//        glDeleteProgram(filterProgram);
//        filterProgram = 0;
//    }
    if (shader != nil) {
        shader = nil;
    }
}

- (void)setInputTexture:(GLint)textureId {
    _inputTexId = textureId;
}

- (GLint)outputTextureID {
    return -1;
}

@end
