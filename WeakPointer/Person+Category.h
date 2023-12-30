//
//  Person+Category.h
//  weakPointer
//
//  Created by LL on 2023/12/27.
//

#import "Person.h"

NS_ASSUME_NONNULL_BEGIN

@interface Person (Category)

@property (nonatomic, weak) TestObject *weakObj;

@end

NS_ASSUME_NONNULL_END
