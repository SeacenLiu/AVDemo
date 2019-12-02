//
//  SCVideoPlayerViewController.m
//  VideoPlayer
//
//  Created by bobo on 2019/12/2.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import "SCVideoPlayerViewController.h"

@interface SCVideoPlayerViewController () <SCFillDataDelegate> {
    SCVideoOutput*                                    _videoOutput;
    SCAudioOutput*                                    _audioOutput;
    NSDictionary*                                   _parameters;
    CGRect                                          _contentFrame;
    
    BOOL                                            _isPlaying;
    EAGLSharegroup *                                _shareGroup;
}
@end

@implementation SCVideoPlayerViewController

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL) usingHWCodec
                          playerStateDelegate:(id<PlayerStateDelegate>) playerStateDelegate
                                   parameters: (NSDictionary *)parameters
{
    return [[SCVideoPlayerViewController alloc] initWithContentPath:path
                                                     contentFrame:frame usingHWCodec:usingHWCodec
                                              playerStateDelegate:playerStateDelegate
                                                       parameters: parameters];
}

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL) usingHWCodec
                          playerStateDelegate:(id<PlayerStateDelegate>) playerStateDelegate
                                   parameters: (NSDictionary *)parameters
                  outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup {
    return [[SCVideoPlayerViewController alloc] initWithContentPath:path
                                                     contentFrame:frame usingHWCodec:usingHWCodec
                                              playerStateDelegate:playerStateDelegate
                                                       parameters:parameters
                                      outputEAGLContextShareGroup:sharegroup];
}

- (void)restart {
    UIView* parentView = [self.view superview];
    [self.view removeFromSuperview];
    [self stop];
    [self start];
    [parentView addSubview:self.view];
}

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL) usingHWCodec
                playerStateDelegate:(id<PlayerStateDelegate>)playerStateDelegate
                         parameters:(NSDictionary *)parameters {
    return [self initWithContentPath:path
                        contentFrame:frame
                        usingHWCodec:usingHWCodec
                 playerStateDelegate:playerStateDelegate
                          parameters:parameters
         outputEAGLContextShareGroup:nil];
}

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL) usingHWCodec
                playerStateDelegate:(id) playerStateDelegate
                         parameters:(NSDictionary *)parameters
        outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup {
    NSAssert(path.length > 0, @"empty path");
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _contentFrame = frame;
        _usingHWCodec = usingHWCodec;
        _parameters = parameters;
        _videoFilePath = path;
        _playerStateDelegate = playerStateDelegate;
        _shareGroup = sharegroup;
        NSLog(@"Enter SCVideoPlayerViewController init, url: %@, h/w enable: %@", _videoFilePath, @(usingHWCodec));
        [self start];
    }
    return self;
}

- (void)start {
    _synchronizer = [[AVSynchronizer alloc] initWithPlayerStateDelegate:_playerStateDelegate];
    __weak SCVideoPlayerViewController *weakSelf = self;
    BOOL isIOS8OrUpper = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0);
    dispatch_async(dispatch_get_global_queue(isIOS8OrUpper ? QOS_CLASS_USER_INTERACTIVE:DISPATCH_QUEUE_PRIORITY_HIGH, 0) , ^{
        __strong SCVideoPlayerViewController *strongSelf = weakSelf;
        if (strongSelf) {
            NSError *error = nil;
            OpenState state = OPEN_FAILED;
            if([_parameters count] > 0){
                state = [strongSelf->_synchronizer openFile:_videoFilePath usingHWCodec:_usingHWCodec parameters:_parameters error:&error];
            } else {
                state = [strongSelf->_synchronizer openFile:_videoFilePath usingHWCodec:_usingHWCodec error:&error];
            }
            _usingHWCodec = [strongSelf->_synchronizer usingHWCodec];
            if(OPEN_SUCCESS == state){
                //启动AudioOutput与VideoOutput
                _videoOutput = [strongSelf createVideoOutputInstance];
                _videoOutput.contentMode = UIViewContentModeScaleAspectFill;
                _videoOutput.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.view.backgroundColor = [UIColor clearColor];
                    [self.view insertSubview:_videoOutput atIndex:0];
                });
                NSInteger audioChannels = [_synchronizer getAudioChannels];
                NSInteger audioSampleRate = [_synchronizer getAudioSampleRate];
                NSInteger bytesPerSample = 2;
                _audioOutput = [[SCAudioOutput alloc] initWithChannels:audioChannels sampleRate:audioSampleRate bytesPerSample:bytesPerSample filleDataDelegate:self];
                [_audioOutput play];
                _isPlaying = YES;
                
                if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(openSucceed)]){
                    [_playerStateDelegate openSucceed];
                }
            } else if(OPEN_FAILED == state){
                if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(connectFailed)]){
                    [_playerStateDelegate connectFailed];
                }
            }
        }
    });
}

- (SCVideoOutput*)createVideoOutputInstance {
    CGRect bounds = self.view.bounds;
    NSInteger textureWidth = [_synchronizer getVideoFrameWidth];
    NSInteger textureHeight = [_synchronizer getVideoFrameHeight];
    return [[SCVideoOutput alloc] initWithFrame:bounds
                                 textureWidth:textureWidth
                                textureHeight:textureHeight
                                 usingHWCodec:_usingHWCodec
                                   shareGroup:_shareGroup];
}

- (SCVideoOutput*)getVideoOutputInstance {
    return _videoOutput;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:_contentFrame];
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //    [self stop];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)play {
    if (_isPlaying)
        return;
    if(_audioOutput){
        [_audioOutput play];
    }
}

- (void)pause {
    if (!_isPlaying)
        return;
    if(_audioOutput){
        [_audioOutput stop];
    }
}

- (void)stop {
    if(_audioOutput){
        [_audioOutput stop];
        _audioOutput = nil;
    }
    if(_synchronizer){
        if([_synchronizer isOpenInputSuccess]){
            [_synchronizer closeFile];
            _synchronizer = nil;
        } else {
            [_synchronizer interrupt];
        }
    }
    if(_videoOutput){
        [_videoOutput destroy];
        [_videoOutput removeFromSuperview];
        _videoOutput = nil;
    }
}

- (BOOL)isPlaying {
    return _isPlaying;
}

- (UIImage *)movieSnapshot {
    if (!_videoOutput) {
        return nil;
    }
    // See Technique Q&A QA1817: https://developer.apple.com/library/ios/qa/qa1817/_index.html
    UIGraphicsBeginImageContextWithOptions(_videoOutput.bounds.size, YES, 0);
    [_videoOutput drawViewHierarchyInRect:_videoOutput.bounds afterScreenUpdates:NO];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (NSInteger)fillAudioData:(SInt16*)sampleBuffer numFrames:(NSInteger)frameNum numChannels:(NSInteger)channels {
    if(_synchronizer && ![_synchronizer isPlayCompleted]){
        [_synchronizer audioCallbackFillData:sampleBuffer numFrames:(UInt32)frameNum numChannels:(UInt32)channels];
        VideoFrame* videoFrame = [_synchronizer getCorrectVideoFrame];
        if(videoFrame){
            [_videoOutput presentVideoFrame:videoFrame];
        }
    } else {
        memset(sampleBuffer, 0, frameNum * channels * sizeof(SInt16));
    }
    return 1;
}

- (void)dealloc {
    NSLog(@"SCVideoPlayerViewController dealloc...");
}

@end
