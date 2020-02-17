//
//  SCGLBaseView.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/17.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "SCGLBaseView.h"
#import <OpenGLES/ES3/gl.h>

@interface SCGLBaseView ()

@property (nonatomic, strong) NSLock *shouldEnableOpenGLLock;
@property (nonatomic, assign) BOOL shouldEnableOpenGL;

@property (nonatomic, assign) BOOL readyToRender;
@property (nonatomic, assign) BOOL stopping;

@end

@implementation SCGLBaseView
{
    EAGLContext*                            _context;
    GLuint                                  _displayFramebuffer;
    GLuint                                  _renderbuffer;
}

// 第一步，配置CAEAGLLayer
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Init
- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // 控制只在应用在前台才执行渲染
        _shouldEnableOpenGLLock = [NSLock new];
        [_shouldEnableOpenGLLock lock];
        _shouldEnableOpenGL = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
        [_shouldEnableOpenGLLock unlock];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        // 第二步，配置CAEAGLLayer属性
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        // 初始化用于GL渲染的串行队列
        _contextQueue = dispatch_queue_create("com.seacen.glBaseView.contextQueue", NULL);
        // 串行队列同步执行（单纯顺序执行，不开线程）
        dispatch_sync(_contextQueue, ^{
            // 第三步，建立 OpenGLES 与 EAGLContext 的连接
            if (![self associateEAGLContextWithOpenGLES]) {
                NSLog(@"EAGLContext 配置失败，OpenGLES 与 EAGLContext无法建立连接");
            }
            
            // 第四步，建立 EAGLContext 与 CAEAGLLayer 的连接
            if (![self associateEAGLContextWithLayer]) {
                NSLog(@"EAGLContext 与 CAEAGLLayer 建立连接失败");
            }
            
            self.readyToRender = [self prepareRender];
        });
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_contextQueue) {
        _contextQueue = nil;
    }
    _context = nil;
}

#pragma mark - Public Method
- (BOOL)prepareRender {
    // 同步执行的方法，用于重写并添加渲染准备逻辑
    return NO;
}

- (void)render {
    if (_stopping) {
        return;
    }
    dispatch_async(_contextQueue, ^{
        [self.shouldEnableOpenGLLock lock];
        if (!self.readyToRender || !self.shouldEnableOpenGL) {
            glFinish();
            [self.shouldEnableOpenGLLock unlock];
            return;
        }
        [self.shouldEnableOpenGLLock unlock];
        
        // *** 绑定部分 ***
        // 绑定当前上下文环境
        [EAGLContext setCurrentContext:_context];
        // 绑定帧缓冲区
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
        // 绑定渲染缓冲区
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        
        // *** 绘制部分 ***
        [self coreRender];
        
        // 展示渲染缓冲区
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    });
}

- (void)coreRender {
    // 异步执行的方法，用于重写并添加核心渲染逻辑
}

- (void)destroy {
    _stopping = true;
    dispatch_sync(_contextQueue, ^{
        if (_displayFramebuffer) {
            glDeleteFramebuffers(1, &_displayFramebuffer);
            _displayFramebuffer = 0;
        }
        if (_renderbuffer) {
            glDeleteRenderbuffers(1, &_renderbuffer);
            _renderbuffer = 0;
        }
        if ([EAGLContext currentContext] == _context) {
            [EAGLContext setCurrentContext:nil];
        }
    });
}

#pragma mark - Private Method
- (EAGLContext*)buildEAGLContext {
    return [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
}

- (BOOL)associateEAGLContextWithOpenGLES {
    BOOL ret = YES;
    _context = [self buildEAGLContext];
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        ret = NO;
    }
    return ret;
}

- (BOOL)associateEAGLContextWithLayer {
    BOOL ret = YES;
    if (_context == nil) {
        return NO;
    }
    // 创建并绑定帧缓冲区到渲染管线
    glGenFramebuffers(1, &_displayFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    // 创建并绑定渲染缓冲区到渲染管线
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    // 为绘制缓冲区分配存储区，此处将 CAEAGLLayer 的绘制存储区作为绘制缓冲区的存储区
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    // 获取绘制缓冲区的像素宽度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    // 获取绘制缓冲区的像素高度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    // 将绘制缓冲区绑定到帧缓冲区
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    // 检查 FrameBuffer 的状态
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"帧缓冲配置未完成: %x", status);
        return FALSE;
    }
    // 检查 OpenGLES 的错误信息
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"配置GL失败 %x", glError);
        return FALSE;
    }
    return ret;
}

#pragma mark - Application Notification
- (void)applicationWillResignActive:(NSNotification *)notification {
    [self.shouldEnableOpenGLLock lock];
    self.shouldEnableOpenGL = NO;
    [self.shouldEnableOpenGLLock unlock];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self.shouldEnableOpenGLLock lock];
    self.shouldEnableOpenGL = YES;
    [self.shouldEnableOpenGLLock unlock];
}

@end
