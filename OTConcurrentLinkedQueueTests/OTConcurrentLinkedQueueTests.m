//
//  OTConcurrentLinkedQueueTests.m
//  OTConcurrentLinkedQueueTests
//
//  Created by Charley Robinson on 2/27/12.
//  Copyright (c) 2012 Tokbox, Inc. All rights reserved.
//

#import "OTConcurrentLinkedQueueTests.h"
#import "OTConcurrentLinkedQueue.h"
#import <libkern/OSAtomic.h>

@implementation OTConcurrentLinkedQueueTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testSerialFillUnfill
{
    int thingsIn = 10000000;
    OTConcurrentLinkedQueue* queue = [[OTConcurrentLinkedQueue alloc] init];
    for (int i = 0; i < thingsIn; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [queue offer:[NSString stringWithFormat:@"%d", i]];
        });
    }
    
    NSLog(@"so far, so good.");
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        __block int thingsOut = 0;
        __block int emptyPollCount = 0;
        while (![queue isEmpty]) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if ([queue poll] != nil) {
                    OSAtomicIncrement32Barrier((int*)&thingsOut);
                } else {
                    OSAtomicIncrement32Barrier((int*)&emptyPollCount);                
                }
            });
        }
        usleep(1000000); //sleep to drain the global queue
        STAssertEquals(thingsOut, thingsIn, @"Number of things");
        NSLog(@"done! out=%d, in=%d, overshot=%d", thingsOut, thingsIn, emptyPollCount);
    });
}

- (void)randomFillUnfill:(double)loadFactor {
    //First, randomly fill/unfill the queue, given some probability of poll/offer
    dispatch_queue_t dispatch_queue = dispatch_queue_create("test-random-fill-unfill-queue", DISPATCH_QUEUE_CONCURRENT);
    int operations = 10000000;
    OTConcurrentLinkedQueue* queue = [[OTConcurrentLinkedQueue alloc] init];
    __block int thingsIn = 0;
    __block int thingsOut = 0;
    srand(time(NULL));
    for (int i = 0; i < operations; i++) {
        OSMemoryBarrier();
        dispatch_async(dispatch_queue, ^{
            int count = i;
            if (rand() >= (RAND_MAX * loadFactor) && ![queue isEmpty]) {
                if ([queue poll] != nil) {
                    OSAtomicIncrement32Barrier((int*)&thingsOut);
                }
            } else {
                [queue offer:[NSString stringWithFormat:@"%d", i]];
                OSAtomicIncrement32Barrier((int*)&thingsIn);
            }
            if (count % (operations / 10) == 0) {
                NSLog(@"%0.f%% complete (%d of %d)", 100*(double)count / (double)operations, count, operations);
            }
        });
    }
    //Drain the dispatch queue of all async poll/offers
    dispatch_barrier_sync(dispatch_queue, ^{
        NSLog(@"Drain dispatch queue");
        NSLog(@"Estimated remaining elements = %d", thingsIn - thingsOut);
    });
    //Dispatch a bunch of polls until queue reports empty on main thread
    dispatch_async(dispatch_queue, ^{
        while ([queue poll] != nil) {
            OSAtomicIncrement32Barrier((int*)&thingsOut);
        }
    });
    //Finally, drain the dispatch queue once again and take score
    dispatch_barrier_sync(dispatch_queue, ^{
        STAssertEquals(thingsOut, thingsIn, @"Number of things");
        if (thingsOut != thingsIn) {
            NSLog(@"Oddly enough, queue says it's got %@", [queue peek]);
        }
        NSLog(@"done! out=%d, in=%d", thingsOut, thingsIn);
    });
    dispatch_release(dispatch_queue);
}


- (void)testRandomFillUnfill {
    NSLog(@"Starting next test: random fill c=0.25");
    [self randomFillUnfill:0.25];
    NSLog(@"Starting next test: random fill c=0.50");
    [self randomFillUnfill:0.50];
    NSLog(@"Starting next test: random fill c=0.75");
    [self randomFillUnfill:0.75];
}


@end
