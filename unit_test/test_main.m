#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

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

int main(int argc, char* argv[]) {
  NSArray<Class> *testCaseClasses = ClassGetSubclasses([XCTestCase class]);
  // NSLog(@"%@", testCaseClasses);

  NSLog(@"test start");

  int executed = 0, failed = 0;

  for(Class clazz in testCaseClasses) {
    NSLog(@"%@ start", clazz);
    [clazz setUp];
    for(NSInvocation* invocation in [clazz testInvocations]) {
      XCTestCase *testCase = [[clazz alloc] initWithInvocation:invocation];
      [testCase setUp];
      [testCase invokeTest];
      [testCase tearDown];
      executed++;
      if([testCase isFailed]) {
        failed++;
      }
    }
    [clazz tearDown];
    NSLog(@"%@ finished", clazz);
  }

  NSLog(@"all test finished");
  NSLog(@"executed %d, failed %d", executed, failed);
}
