//
//  main.m
//  weakPointer
//
//  Created by LL on 2023/12/22.
//

#import <Foundation/Foundation.h>

#import "lil_objc_weak.h"
#import "Person.h"
#import "lil_objc_category_weak.h"
#import "Person+Category.h"


int main(int argc, const char * argv[]) {
    Person *weakP1 = nil;
    Person *weakP2 = nil;
    
    {
        Person *p = [[Person alloc] init];
        
        // 编译器会将 `weakP1 = p;` 自动转换成以下类似代码。
        lil_objc_storeWeak((void *)&weakP1, p);// 等价于 `weakP1 = p;`
        lil_objc_storeWeak((void *)&weakP2, p);// 等价于 `weakP2 = p;`
        
        NSLog(@"Person 对象释放前对弱指针的打印：weakP1: %@, weakP2: %@", weakP1, weakP2);
    }
    
    NSLog(@"Person 对象释放后对弱指针的打印：weakP1: %@, weakP2: %@", weakP1, weakP2);
    
    NSLog(@"\n");
    NSLog(@"------------- 下面是对分类弱属性的测试 ---------------------");
    NSLog(@"\n");
    
    Person *person = [[Person alloc] init];
    
    {
        TestObject *obj = [[TestObject alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-unsafe-retained-assign"
        person.weakObj = (__bridge id)(void *)lil_objc_category_storeWeak(person, "weakObj", obj);// 等价于 `per.weakObj = obj;`
#pragma clang diagnostic pop
        
        NSLog(@"TestObject 对象释放前对 Person 对象的分类弱属性的打印：person.weakObj: %@", person.weakObj);
    }
    
    NSLog(@"TestObject 对象释放后对 Person 对象的分类弱属性的打印：person.weakObj: %@", person.weakObj);
    
    return 0;
}
