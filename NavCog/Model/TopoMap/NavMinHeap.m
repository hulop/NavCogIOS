/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Contributors:
 *  Chengxiong Ruan (CMU) - initial API and implementation
 *******************************************************************************/

#import "NavMinHeap.h"

@interface NavMinHeap ()

@property (strong, nonatomic) NSMutableArray *dataArray;
@property (nonatomic) int heapSize;
@property (nonatomic) int curSize;

@end

@implementation NavMinHeap

- (void)initHeapWithSize:(int)size {
    _heapSize = size;
    _curSize = 0;
    _dataArray = [NSMutableArray arrayWithCapacity:size];
    NavNode *dummy = [[NavNode alloc] init];
    for (int i = 0; i < size; i++) {
        [_dataArray addObject:dummy];
    }
}

- (void)offer:(NavNode *)node {
    if (_curSize == _heapSize) {
        assert(@"heap overflow");
    } else {
        [_dataArray replaceObjectAtIndex:_curSize withObject:node];
        [self siftUp:_curSize];
        ++_curSize;
    }
}

- (NavNode *)peek {
    if (_curSize == 0) {
        return nil;
    } else {
        return [_dataArray objectAtIndex:0];
    }
}

- (NavNode *)poll {
    if (_curSize == 0) {
        return nil;
    } else {
        NavNode *tmp = [_dataArray objectAtIndex:0];
        --_curSize;
        [_dataArray replaceObjectAtIndex:0 withObject:[_dataArray objectAtIndex:_curSize]];
        if (_curSize > 0) {
            [self siftDown:0];
        }
        return tmp;
    }
}

- (void)siftUp:(int)nodeIndex {
    if (nodeIndex > 0) {
        int parentIndex = [self getParentIndex:nodeIndex];
        NavNode *node = [_dataArray objectAtIndex:nodeIndex];
        NavNode *parent = [_dataArray objectAtIndex:parentIndex];
        if (node.distFromStartNode < parent.distFromStartNode) {
            node.indexInHeap = parentIndex;
            parent.indexInHeap = nodeIndex;
            NavNode *tmp = node;
            [_dataArray replaceObjectAtIndex:nodeIndex withObject:parent];
            [_dataArray replaceObjectAtIndex:parentIndex withObject:tmp];
            [self siftUp:parentIndex];
        }
    }
}

- (void)siftDown:(int)nodeIndex {
    int leftIndex, rightIndex, minIndex;
    leftIndex = [self getLeftChildIndex:nodeIndex];
    rightIndex = [self getRightChildIndex:nodeIndex];
    if (rightIndex >= _curSize) {
        if (leftIndex >= _curSize) {
            return;
        } else {
            minIndex = leftIndex;
        }
    } else {
        if (leftIndex >= _curSize) {
            minIndex = rightIndex;
        } else {
            if ([[_dataArray objectAtIndex:leftIndex] distFromStartNode] < [[_dataArray objectAtIndex:rightIndex] distFromStartNode]) {
                minIndex = leftIndex;
            } else {
                minIndex = rightIndex;
            }
        }
    }
    NavNode *node = [_dataArray objectAtIndex:nodeIndex];
    NavNode *child = [_dataArray objectAtIndex:minIndex];
    if (node.distFromStartNode > child.distFromStartNode) {
        node.indexInHeap = minIndex;
        child.indexInHeap = nodeIndex;
        NavNode *tmp = node;
        [_dataArray replaceObjectAtIndex:nodeIndex withObject:child];
        [_dataArray replaceObjectAtIndex:minIndex withObject:tmp];
        [self siftDown:minIndex];
    }
    
}

- (void)siftAndUpdateNode:(NavNode *)node withNewDist:(int)newDist {
    if (newDist > node.distFromStartNode) {
        node.distFromStartNode = newDist;
        [self siftDown:node.indexInHeap];
    } else {
        node.distFromStartNode = newDist;
        [self siftUp:node.indexInHeap];
    }
}

- (int)getParentIndex:(int)nodeIndex {
    return (nodeIndex - 1) / 2;
}

- (int)getLeftChildIndex:(int)nodeIndex {
    return 2 * nodeIndex + 1;
}

- (int)getRightChildIndex:(int)nodeIndex {
    return 2 * nodeIndex + 2;
}

- (int)getSize {
    return _curSize;
}

@end
