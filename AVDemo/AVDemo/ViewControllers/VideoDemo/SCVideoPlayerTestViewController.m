//
//  SCVideoPlayerTestViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/7/11.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "SCVideoPlayerTestViewController.h"
#import "ELVideoViewPlayerController.h"
#import "NSString+Path.h"

NSString * const MIN_BUFFERED_DURATION = @"Min Buffered Duration";
NSString * const MAX_BUFFERED_DURATION = @"Max Buffered Duration";

@interface SCVideoPlayerTestViewController ()
{
    NSMutableDictionary*            _requestHeader;
}
@end

@implementation SCVideoPlayerTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _requestHeader = [NSMutableDictionary dictionary];
    _requestHeader[MIN_BUFFERED_DURATION] = @(2.0f);
    _requestHeader[MAX_BUFFERED_DURATION] = @(4.0f);
}

- (IBAction)playlocalFileTest:(id)sender {
    NSLog(@"forward local player page...");
    NSString* videoFilePath = [NSString bundlePath:@"test.flv"];
    BOOL usingHWCodec = NO;
    ELVideoViewPlayerController *vc = [ELVideoViewPlayerController viewControllerWithContentPath:videoFilePath contentFrame:self.view.bounds usingHWCodec:usingHWCodec parameters:_requestHeader];
    [[self navigationController] pushViewController:vc animated:YES];
}


@end
