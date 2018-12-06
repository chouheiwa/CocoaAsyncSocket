//
//  GCDAsyncSocketPreBuffer.h
//  iOS CocoaAsyncSocket
//
//  Created by Di on 2018/12/5.
//  Copyright © 2018 Robbie Hanson. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A PreBuffer is used when there is more data available on the socket
 * than is being requested by current read request.
 * In this case we slurp up all data from the socket (to minimize sys calls),
 * and store additional yet unread data in a "prebuffer".
 *
 * The prebuffer is entirely drained before we read from the socket again.
 * In other words, a large chunk of data is written is written to the prebuffer.
 * The prebuffer is then drained via a series of one or more reads (for subsequent read request(s)).
 *
 * A ring buffer was once used for this purpose.
 * But a ring buffer takes up twice as much memory as needed (double the size for mirroring).
 * In fact, it generally takes up more than twice the needed size as everything has to be rounded up to vm_page_size.
 * And since the prebuffer is always completely drained after being written to, a full ring buffer isn't needed.
 *
 * The current design is very simple and straight-forward, while also keeping memory requirements lower.
 **/


/**
 这个类的用途是做缓存读写的
 */
@interface GCDAsyncSocketPreBuffer : NSObject
{
    // 预先缓冲区指针
    uint8_t *preBuffer;
    // 原先缓冲区大小
    size_t preBufferSize;
    // 读取数据位置的指针
    uint8_t *readPointer;
    // 写入数据位置指针
    uint8_t *writePointer;
}

- (id)initWithCapacity:(size_t)numBytes;

- (void)ensureCapacityForWrite:(size_t)numBytes;

- (size_t)availableBytes;
- (uint8_t *)readBuffer;

- (void)getReadBuffer:(uint8_t **)bufferPtr availableBytes:(size_t *)availableBytesPtr;

- (size_t)availableSpace;
- (uint8_t *)writeBuffer;

- (void)getWriteBuffer:(uint8_t **)bufferPtr availableSpace:(size_t *)availableSpacePtr;

- (void)didRead:(size_t)bytesRead;
- (void)didWrite:(size_t)bytesWritten;

- (void)reset;

@end
