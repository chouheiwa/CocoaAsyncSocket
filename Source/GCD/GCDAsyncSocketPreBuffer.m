//
//  GCDAsyncSocketPreBuffer.m
//  iOS CocoaAsyncSocket
//
//  Created by Di on 2018/12/5.
//  Copyright © 2018 Robbie Hanson. All rights reserved.
//

#import "GCDAsyncSocketPreBuffer.h"

@implementation GCDAsyncSocketPreBuffer

- (id)initWithCapacity:(size_t)numBytes
{
    if ((self = [super init]))
    {
        preBufferSize = numBytes;
        preBuffer = malloc(preBufferSize);
        
        readPointer = preBuffer;
        writePointer = preBuffer;
    }
    return self;
}

- (void)dealloc
{
    if (preBuffer)
        free(preBuffer);
}

/**
 确保容量足够写入
 
 @param numBytes 写入数据大小
 */
- (void)ensureCapacityForWrite:(size_t)numBytes
{
    // 计算剩余可用容量大小
    size_t availableSpace = [self availableSpace];
    // 判断空间容量是否足够
    if (numBytes > availableSpace)
    {
        // 计算需要额外拓展的空间量
        size_t additionalBytes = numBytes - availableSpace;
        // 计算需求空间总量
        size_t newPreBufferSize = preBufferSize + additionalBytes;
        // 扩展内存
        uint8_t *newPreBuffer = realloc(preBuffer, newPreBufferSize);
        // 计算读指针偏移量
        size_t readPointerOffset = readPointer - preBuffer;
        // 计算写指针偏移量
        size_t writePointerOffset = writePointer - preBuffer;
        // 切换内存指针
        preBuffer = newPreBuffer;
        // 重新赋值大小
        preBufferSize = newPreBufferSize;
        // 切换读指针位置
        readPointer = preBuffer + readPointerOffset;
        // 切换写指针位置
        writePointer = preBuffer + writePointerOffset;
    }
}
// 剩余未读自己量
- (size_t)availableBytes
{
    return writePointer - readPointer;
}
// 读取指针
- (uint8_t *)readBuffer
{
    return readPointer;
}

/**
 将内容写入给定指针中，同时写入数据长度
 
 @param bufferPtr 给定需要写入内容指针
 @param availableBytesPtr 需要返回可用字节空间
 */
- (void)getReadBuffer:(uint8_t **)bufferPtr availableBytes:(size_t *)availableBytesPtr
{
    if (bufferPtr) *bufferPtr = readPointer;
    if (availableBytesPtr) *availableBytesPtr = [self availableBytes];
}

/**
 已经阅读多少字节长度
 
 @param bytesRead 字节长度
 */
- (void)didRead:(size_t)bytesRead
{
    // 将读取指针偏移
    readPointer += bytesRead;
    // 当读指针遇到写指针的时候，说明已经读完毕了
    if (readPointer == writePointer)
    {
        // 清空读写指针
        readPointer  = preBuffer;
        writePointer = preBuffer;
    }
}
// 计算可用容量
- (size_t)availableSpace
{
    return preBufferSize - (writePointer - preBuffer);
}
// 返回写指针
- (uint8_t *)writeBuffer
{
    return writePointer;
}

/**
 获取写指针 与剩余可用空间
 
 @param bufferPtr 传入二级指针
 @param availableSpacePtr 大小
 */
- (void)getWriteBuffer:(uint8_t **)bufferPtr availableSpace:(size_t *)availableSpacePtr
{
    if (bufferPtr) *bufferPtr = writePointer;
    if (availableSpacePtr) *availableSpacePtr = [self availableSpace];
}

/**
 已经写入多少字节长度
 
 @param bytesWritten 写入字节长度
 */
- (void)didWrite:(size_t)bytesWritten
{
    writePointer += bytesWritten;
}

/**
 重置
 */
- (void)reset
{
    readPointer  = preBuffer;
    writePointer = preBuffer;
}

@end
