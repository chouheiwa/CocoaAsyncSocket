//
//  GCDAsyncReadPacket.m
//  iOS CocoaAsyncSocket
//
//  Created by Di on 2018/12/5.
//  Copyright © 2018 Robbie Hanson. All rights reserved.
//

#import "GCDAsyncReadPacket.h"
#import "GCDAsyncSocketPreBuffer.h"

@implementation GCDAsyncReadPacket

- (id)initWithData:(NSMutableData *)data
       startOffset:(NSUInteger)s
         maxLength:(NSUInteger)m
           timeout:(NSTimeInterval)t
        readLength:(NSUInteger)l
        terminator:(NSData *)e
               tag:(long)i
{
    if((self = [super init]))
    {
        bytesDone = 0;
        maxLength = m;
        timeout = t;
        readLength = l;
        term = [e copy];
        tag = i;
        
        if (data)
        {
            buffer = data;
            startOffset = s;
            bufferOwner = NO;
            originalBufferLength = [data length];
        }
        else
        {
            if (readLength > 0)
                buffer = [[NSMutableData alloc] initWithLength:readLength];
            else
                buffer = [[NSMutableData alloc] initWithLength:0];
            
            startOffset = 0;
            bufferOwner = YES;
            originalBufferLength = 0;
        }
    }
    return self;
}

/**
 * Increases the length of the buffer (if needed) to ensure a read of the given size will fit.
 **/

/**
 确保给定额外数据长度足够

 @param bytesToRead 额外数据长度
 */
- (void)ensureCapacityForAdditionalDataOfLength:(NSUInteger)bytesToRead
{
    // 获取缓存区长度
    NSUInteger buffSize = [buffer length];
    // 计算已经使用
    NSUInteger buffUsed = startOffset + bytesDone;
    // 计算剩余空间
    NSUInteger buffSpace = buffSize - buffUsed;
    // 判断是否需要扩容
    if (bytesToRead > buffSpace)
    {
        NSUInteger buffInc = bytesToRead - buffSpace;
        
        [buffer increaseLengthBy:buffInc];
    }
}

/**
 * This method is used when we do NOT know how much data is available to be read from the socket.
 * This method returns the default value unless it exceeds the specified readLength or maxLength.
 *
 * Furthermore, the shouldPreBuffer decision is based upon the packet type,
 * and whether the returned value would fit in the current buffer without requiring a resize of the buffer.
 **/

/**
 当我们不知道有可能从socket连接中获得多少数据的时候我们需要使用这个方法
 这个方法将返回一个默认值，除非他达到了我们给定的读取长度或者是最大长度

 @param defaultValue 给定默认数值
 @param shouldPreBufferPtr 是否需要准备缓存
 @return 返回一个长度
 */
- (NSUInteger)optimalReadLengthWithDefault:(NSUInteger)defaultValue shouldPreBuffer:(BOOL *)shouldPreBufferPtr
{
    NSUInteger result;
    //当我们知道读取的字节长度的时候
    if (readLength > 0)
    {
        // Read a specific length of data
        
        // 从定义中获取长度
        result = readLength - bytesDone;
        
        // There is no need to prebuffer since we know exactly how much data we need to read.
        // Even if the buffer isn't currently big enough to fit this amount of data,
        // it would have to be resized eventually anyway.
        // 当我们知道究竟有多少数据需要读取的时候，我们现在的缓存区不够大，这个缓存区不论如何最终都会被重新分配大小
        if (shouldPreBufferPtr)
            *shouldPreBufferPtr = NO;
    }
    else
    {
        // Either reading until we find a specified terminator,
        // or we're simply reading all available data.
        //
        // In other words, one of:
        //
        // - readDataToData packet
        // - readDataWithTimeout packet
        // 否则我们将会继续读取直到我们找到一个制定的二进制数据 或者 我们将简单的读完所有可能数据
        
        // 如果给定了最大长度
        if (maxLength > 0)
            result =  MIN(defaultValue, (maxLength - bytesDone));
        else
            result = defaultValue;
        
        // Since we don't know the size of the read in advance,
        // the shouldPreBuffer decision is based upon whether the returned value would fit
        // in the current buffer without requiring a resize of the buffer.
        //
        // This is because, in all likelyhood, the amount read from the socket will be less than the default value.
        // Thus we should avoid over-allocating the read buffer when we can simply use the pre-buffer instead.
        
        // 当我们不能知道预先能读取的数据容量的时候
        // shouldPreBuffer 这个参数 会根据 result 能否在当前这个缓存区而不需要重新分配大小
        //
        // 因为，在所有的可能性里，从连接中获取的数据长度都会小于默认的大小
        // 当我们能简单的提供预先缓存区替代的时候，我们需要避免重新初始化 读取缓存 (因为开销大)
        if (shouldPreBufferPtr)
        {
            // 获取缓存区大小
            NSUInteger buffSize = [buffer length];
            // 计算已经使用大小
            NSUInteger buffUsed = startOffset + bytesDone;
            // 计算剩余空间
            NSUInteger buffSpace = buffSize - buffUsed;
            // 当缓存空间 > 默认值得时候，不需要给定额外缓存空间
            if (buffSpace >= result)
                *shouldPreBufferPtr = NO;
            else
                *shouldPreBufferPtr = YES;
        }
    }
    
    return result;
}

/**
 * For read packets without a set terminator, returns the amount of data
 * that can be read without exceeding the readLength or maxLength.
 *
 * The given parameter indicates the number of bytes estimated to be available on the socket,
 * which is taken into consideration during the calculation.
 *
 * The given hint MUST be greater than zero.
 **/


/**
 这个方法只能在没有给定结束数据的时候调用
 可以在不超过最大长度或读取长度的情况下返回数据的长度

 @param bytesAvailable socket 可以返回的限制 (必须大于0)
 @return 数据长度
 */
- (NSUInteger)readLengthForNonTermWithHint:(NSUInteger)bytesAvailable
{
    NSAssert(term == nil, @"This method does not apply to term reads");
    NSAssert(bytesAvailable > 0, @"Invalid parameter: bytesAvailable");
    
    if (readLength > 0)
    {
        // Read a specific length of data
        // 给定读取大小的时候
        return MIN(bytesAvailable, (readLength - bytesDone));
        
        // No need to avoid resizing the buffer.
        // If the user provided their own buffer,
        // and told us to read a certain length of data that exceeds the size of the buffer,
        // then it is clear that our code will resize the buffer during the read operation.
        //
        // This method does not actually do any resizing.
        // The resizing will happen elsewhere if needed.
        
        // 无需调整缓存区大小
        // 如果用户提供了他们自己的缓存区，同时告诉我们超过缓存区大小的数据长度，那么我们的程序将在读取操作的时候重新分配缓存区大小
        //
        // 这个方法不会进行任何调整缓存区大小的行为，如果的需要的话，这个行为将会在其他位置发生
    }
    else
    {
        // Read all available data
        // 读取所有可能字节的时候
        NSUInteger result = bytesAvailable;
        
        if (maxLength > 0)
        {
            result = MIN(result, (maxLength - bytesDone));
        }
        
        // No need to avoid resizing the buffer.
        // If the user provided their own buffer,
        // and told us to read all available data without giving us a maxLength,
        // then it is clear that our code might resize the buffer during the read operation.
        //
        // This method does not actually do any resizing.
        // The resizing will happen elsewhere if needed.
        
        return result;
    }
}

/**
 * For read packets with a set terminator, returns the amount of data
 * that can be read without exceeding the maxLength.
 *
 * The given parameter indicates the number of bytes estimated to be available on the socket,
 * which is taken into consideration during the calculation.
 *
 * To optimize memory allocations, mem copies, and mem moves
 * the shouldPreBuffer boolean value will indicate if the data should be read into a prebuffer first,
 * or if the data can be read directly into the read packet's buffer.
 **/

/**
 调用这个方法的时候，需要预先设置结束二进制码。将会在不超过设置最大长度的情况下，返回数据的长度

 @param bytesAvailable 给定的预估字符串含量，会被考虑在计算过程中
 @param shouldPreBufferPtr 这个参数将会返回是否需要准备预缓存区
 @return 返回读取字节长度
 */
- (NSUInteger)readLengthForTermWithHint:(NSUInteger)bytesAvailable shouldPreBuffer:(BOOL *)shouldPreBufferPtr
{
    NSAssert(term != nil, @"This method does not apply to non-term reads");
    NSAssert(bytesAvailable > 0, @"Invalid parameter: bytesAvailable");
    
    NSUInteger result = bytesAvailable;
    
    if (maxLength > 0)
    {
        result = MIN(result, (maxLength - bytesDone));
    }
    
    // Should the data be read into the read packet's buffer, or into a pre-buffer first?
    //
    // One would imagine the preferred option is the faster one.
    // So which one is faster?
    //
    // Reading directly into the packet's buffer requires:
    // 1. Possibly resizing packet buffer (malloc/realloc)
    // 2. Filling buffer (read)
    // 3. Searching for term (memcmp)
    // 4. Possibly copying overflow into prebuffer (malloc/realloc, memcpy)
    //
    // Reading into prebuffer first:
    // 1. Possibly resizing prebuffer (malloc/realloc)
    // 2. Filling buffer (read)
    // 3. Searching for term (memcmp)
    // 4. Copying underflow into packet buffer (malloc/realloc, memcpy)
    // 5. Removing underflow from prebuffer (memmove)
    //
    // Comparing the performance of the two we can see that reading
    // data into the prebuffer first is slower due to the extra memove.
    //
    // However:
    // The implementation of NSMutableData is open source via core foundation's CFMutableData.
    // Decreasing the length of a mutable data object doesn't cause a realloc.
    // In other words, the capacity of a mutable data object can grow, but doesn't shrink.
    //
    // This means the prebuffer will rarely need a realloc.
    // The packet buffer, on the other hand, may often need a realloc.
    // This is especially true if we are the buffer owner.
    // Furthermore, if we are constantly realloc'ing the packet buffer,
    // and then moving the overflow into the prebuffer,
    // then we're consistently over-allocating memory for each term read.
    // And now we get into a bit of a tradeoff between speed and memory utilization.
    //
    // The end result is that the two perform very similarly.
    // And we can answer the original question very simply by another means.
    //
    // If we can read all the data directly into the packet's buffer without resizing it first,
    // then we do so. Otherwise we use the prebuffer.
    
    // 数据是应该直接被这个类处理还是需要一个预缓存区？
    //
    // 所有人都更倾向于更快的一个，那么什么才是更快的?
    //
    // 直接读取缓存需要的步骤:
    // 1. 可能重新分配缓存区大小 (malloc/realloc 调用)
    // 2. 填充缓存区 (read)
    // 3. 搜索终止数据 (memcmp)
    // 4. 可能拷贝会溢出的数据到缓存区中 (malloc/realloc, memcpy)
    //
    // 读取预缓存需要的步骤:
    // 1. 可能重新分配缓存区大小 (malloc/realloc 调用)
    // 2. 填充缓存区 (read)
    // 3. 搜索终止数据 (memcmp)
    // 4. 复制下溢数据到读取缓存区 (malloc/realloc, memcpy)
    // 5. 从预缓存区中删除下溢数据 (memmove)
    //
    // 当我们比较两者的表现后可以发现由于需要做额外的删除操作(memove)所以将数据先写入到预缓存区会更慢
    //
    // 可是:
    // 通过观察NSMutableData 的开源库Core Foundation实现可以看出:
    // 减少NSMutableData 的数据不会触发 realloc 操作
    // 换句话说，NSMutableData 的内存占用量只会增长不会减少
    //
    // 这意味着如果用NSMutableData作为预先缓存区的时候将会很少需求realloc
    // 但是读取区的缓存，可能经常需要重新realloc
    // 特别是当我们是缓存区拥有者的时候
    // 此外，如果我们持续的realloc'ing 读取缓存然后将溢出数据移动到预缓存区，然后我们持续初始化额外内存区域到读取到终止二进制
    // 现在我们需要权衡一下速度和内存占用的情况了
    //
    // 最终的结果是，这两个非常相似(所以前面是在说什么-_-纯粹的吐槽)
    // 我们可以很简单的从另一个方面回答原来的问题
    //
    // 如果我们能在不用重新给当前缓存重新分值得情况下直接读取到所有数据，我们就可以使用缓存。其余情况下，我们使用预缓存
    if (shouldPreBufferPtr)
    {
        // 计算缓存区大小
        NSUInteger buffSize = [buffer length];
        // 或得已使用长度
        NSUInteger buffUsed = startOffset + bytesDone;
        // 根据上述推论进行判断
        if ((buffSize - buffUsed) >= result)
            *shouldPreBufferPtr = NO;
        else
            *shouldPreBufferPtr = YES;
    }
    
    return result;
}

/**
 * For read packets with a set terminator,
 * returns the amount of data that can be read from the given preBuffer,
 * without going over a terminator or the maxLength.
 *
 * It is assumed the terminator has not already been read.
 **/


/**
 这个方法只能在设置了终止二进制的时候被调用
 返回从预缓存区中可以获得的二进制数据的长度
 @param preBuffer 预缓存器
 @param foundPtr 是否搜索到
 @return 数据长度
 */
- (NSUInteger)readLengthForTermWithPreBuffer:(GCDAsyncSocketPreBuffer *)preBuffer found:(BOOL *)foundPtr
{
    NSAssert(term != nil, @"This method does not apply to non-term reads");
    NSAssert([preBuffer availableBytes] > 0, @"Invoked with empty pre buffer!");
    
    // We know that the terminator, as a whole, doesn't exist in our own buffer.
    // But it is possible that a _portion_ of it exists in our buffer.
    // So we're going to look for the terminator starting with a portion of our own buffer.
    //
    // Example:
    //
    // term length      = 3 bytes
    // bytesDone        = 5 bytes
    // preBuffer length = 5 bytes
    //
    // If we append the preBuffer to our buffer,
    // it would look like this:
    //
    // ---------------------
    // |B|B|B|B|B|P|P|P|P|P|
    // ---------------------
    //
    // So we start our search here:
    //
    // ---------------------
    // |B|B|B|B|B|P|P|P|P|P|
    // -------^-^-^---------
    //
    // And move forwards...
    //
    // ---------------------
    // |B|B|B|B|B|P|P|P|P|P|
    // ---------^-^-^-------
    //
    // Until we find the terminator or reach the end.
    //
    // ---------------------
    // |B|B|B|B|B|P|P|P|P|P|
    // ---------------^-^-^-
    
    // 当执行到这个方法的时候我们已经知道了，终止特征数据作为一个整体，已经不存在于我们的缓存数据中了。
    // 但是它可能会部分存在于我们的缓存区中
    // 因此我们应该在我们的缓存区继续寻找结束符的部分
    //
    // 例子(就不翻译了，这个应该不是很难理解)
    
    BOOL found = NO;
    // 获取结束特征符的长度
    NSUInteger termLength = [term length];
    // 获取缓存区有效数据的长度
    NSUInteger preBufferLength = [preBuffer availableBytes];
    // 如果已经获取完成的长度 < 结束特征长度 那么就不用搜索了
    if ((bytesDone + preBufferLength) < termLength)
    {
        // Not enough data for a full term sequence yet
        return preBufferLength;
    }
    NSUInteger maxPreBufferLength;
    if (maxLength > 0) {
        maxPreBufferLength = MIN(preBufferLength, (maxLength - bytesDone));
        
        // Note: maxLength >= termLength
    }
    else {
        maxPreBufferLength = preBufferLength;
    }
    // 声明一个长度为终止二进制的数组
    uint8_t seq[termLength];
    // 获取不可变终止二进制
    const void *termBuf = [term bytes];
    // 获取可以操作结束符更小值
    NSUInteger bufLen = MIN(bytesDone, (termLength - 1));
    // 获取应该开始的指针位置
    uint8_t *buf = (uint8_t *)[buffer mutableBytes] + startOffset + bytesDone - bufLen;
    // 
    NSUInteger preLen = termLength - bufLen;
    const uint8_t *pre = [preBuffer readBuffer];
    
    NSUInteger loopCount = bufLen + maxPreBufferLength - termLength + 1; // Plus one. See example above.
    
    NSUInteger result = maxPreBufferLength;
    
    NSUInteger i;
    for (i = 0; i < loopCount; i++)
    {
        if (bufLen > 0)
        {
            // Combining bytes from buffer and preBuffer
            
            memcpy(seq, buf, bufLen);
            memcpy(seq + bufLen, pre, preLen);
            
            if (memcmp(seq, termBuf, termLength) == 0)
            {
                result = preLen;
                found = YES;
                break;
            }
            
            buf++;
            bufLen--;
            preLen++;
        }
        else
        {
            // Comparing directly from preBuffer
            
            if (memcmp(pre, termBuf, termLength) == 0)
            {
                NSUInteger preOffset = pre - [preBuffer readBuffer]; // pointer arithmetic
                
                result = preOffset + termLength;
                found = YES;
                break;
            }
            
            pre++;
        }
    }
    
    // There is no need to avoid resizing the buffer in this particular situation.
    
    if (foundPtr) *foundPtr = found;
    return result;
}

/**
 * For read packets with a set terminator, scans the packet buffer for the term.
 * It is assumed the terminator had not been fully read prior to the new bytes.
 *
 * If the term is found, the number of excess bytes after the term are returned.
 * If the term is not found, this method will return -1.
 *
 * Note: A return value of zero means the term was found at the very end.
 *
 * Prerequisites:
 * The given number of bytes have been added to the end of our buffer.
 * Our bytesDone variable has NOT been changed due to the prebuffered bytes.
 **/
- (NSInteger)searchForTermAfterPreBuffering:(ssize_t)numBytes
{
    NSAssert(term != nil, @"This method does not apply to non-term reads");
    
    // The implementation of this method is very similar to the above method.
    // See the above method for a discussion of the algorithm used here.
    
    uint8_t *buff = [buffer mutableBytes];
    NSUInteger buffLength = bytesDone + numBytes;
    
    const void *termBuff = [term bytes];
    NSUInteger termLength = [term length];
    
    // Note: We are dealing with unsigned integers,
    // so make sure the math doesn't go below zero.
    
    NSUInteger i = ((buffLength - numBytes) >= termLength) ? (buffLength - numBytes - termLength + 1) : 0;
    
    while (i + termLength <= buffLength)
    {
        uint8_t *subBuffer = buff + startOffset + i;
        
        if (memcmp(subBuffer, termBuff, termLength) == 0)
        {
            return buffLength - (i + termLength);
        }
        
        i++;
    }
    
    return -1;
}


@end
