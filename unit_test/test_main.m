#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <emscripten.h>

// https://stackoverflow.com/questions/7923586/objective-c-get-list-of-subclasses-from-superclass
NSArray *ClassGetSubclasses(Class parentClass)
{
  int numClasses = objc_getClassList(NULL, 0);
  Class *classes = NULL;

  classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
  numClasses = objc_getClassList(classes, numClasses);

  NSMutableArray *result = [NSMutableArray array];
  for (NSInteger i = 0; i < numClasses; i++)
  {
    Class superClass = classes[i];
    do
    {
      superClass = class_getSuperclass(superClass);
    } while(superClass && superClass != parentClass);

    if (superClass == nil)
    {
      continue;
    }

    [result addObject:classes[i]];
  }

  free(classes);

  return result;
}

@interface XCTestCase (async)
- (void)invokeTestAsyncWithCallback:(void (^)(void))callback;
@property(getter=isFailed) BOOL failed;
@end

int executed = 0, failed = 0;

void runTestCaseMethod(Class clazz, NSInvocation* invocation, void (^callback)(void))
{
  // NSLog(@"%s %@ %@", __FUNCTION__, clazz, invocation);
  // dispatch_async(dispatch_get_current_queue, callback);
  // return;

  XCTestCase *testCase = [[clazz alloc] initWithInvocation:invocation];
  [testCase setUp];
  [testCase invokeTestAsyncWithCallback:^{
    [testCase tearDown];
    executed++;
    if([testCase isFailed]) {
      failed++;
    }
    callback();
  }];
}

void runTestCaseMethodAndNext(Class clazz, NSEnumerator *enumerator, void (^done)(void))
{
  NSInvocation* invocation = [enumerator nextObject];
  if(invocation) {
    runTestCaseMethod(clazz, invocation, ^{
      runTestCaseMethodAndNext(clazz, enumerator, done);
    });
  } else {
    done();
  }
}

void runTestCase(Class clazz, void (^callback)(void))
{
  NSLog(@"%@ start", clazz);
  [clazz setUp];
  NSEnumerator *enumerator = [[clazz testInvocations] objectEnumerator];
#if !__has_feature(objc_arc)
  [enumerator retain];
#endif
  runTestCaseMethodAndNext(clazz, enumerator, ^{
#if !__has_feature(objc_arc)
    [enumerator release];
#endif
    [clazz tearDown];
    NSLog(@"%@ finished", clazz);
    callback();
  });
}

void runTestCaseAndNext(NSEnumerator *enumerator, void (^done)(void))
{
  Class clazz = [enumerator nextObject];
  if(clazz) {
    runTestCase(clazz, ^{
      runTestCaseAndNext(enumerator, done);
    });
  } else {
    done();
  }
}

int main(int argc, char* argv[]) {
  NSArray<Class> *testCaseClasses = ClassGetSubclasses([XCTestCase class]);
  // NSLog(@"%@", testCaseClasses);

  NSLog(@"test start");
  NSEnumerator *enumerator = [testCaseClasses objectEnumerator];
#if !__has_feature(objc_arc)
  [enumerator retain];
#endif
  runTestCaseAndNext(enumerator, ^{
#if !__has_feature(objc_arc)
    [enumerator release];
#endif
    NSLog(@"all test finished");
    NSLog(@"executed: %d, failed: %d", executed, failed);
    emscripten_cancel_main_loop();
    emscripten_force_exit(failed > 127 ? 127 : failed);
  });

  dispatch_main();
}
