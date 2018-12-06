//
//  GCDAsyncReadPacket.h
//  iOS CocoaAsyncSocket
//
//  Created by Di on 2018/12/5.
//  Copyright © 2018 Robbie Hanson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GCDAsyncSocketPreBuffer;

@interface GCDAsyncReadPacket : NSObject
{
@public
    NSMutableData *buffer;
    //起始偏移量
    NSUInteger startOffset;
    //完成字节
    NSUInteger bytesDone;
    //最大长度
    NSUInteger maxLength;
    //超时时间
    NSTimeInterval timeout;
    NSUInteger readLength;
    // 给定数据结尾(遇到制定二进制结束读取)
    NSData *term;
    BOOL bufferOwner;
    NSUInteger originalBufferLength;
    long tag;
}
- (id)initWithData:(NSMutableData *)d
       startOffset:(NSUInteger)s
         maxLength:(NSUInteger)m
           timeout:(NSTimeInterval)t
        readLength:(NSUInteger)l
        terminator:(NSData *)e
               tag:(long)i;

- (void)ensureCapacityForAdditionalDataOfLength:(NSUInteger)bytesToRead;

- (NSUInteger)optimalReadLengthWithDefault:(NSUInteger)defaultValue shouldPreBuffer:(BOOL *)shouldPreBufferPtr;

- (NSUInteger)readLengthForNonTermWithHint:(NSUInteger)bytesAvailable;
- (NSUInteger)readLengthForTermWithHint:(NSUInteger)bytesAvailable shouldPreBuffer:(BOOL *)shouldPreBufferPtr;
- (NSUInteger)readLengthForTermWithPreBuffer:(GCDAsyncSocketPreBuffer *)preBuffer found:(BOOL *)foundPtr;

- (NSInteger)searchForTermAfterPreBuffering:(ssize_t)numBytes;

@end
