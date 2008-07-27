/*!
@file macro.m
@description Nu macros.
@copyright Copyright (c) 2007 Neon Design Technology, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
#import "macro.h"
#import "defmacro.h"
#import "cell.h"
#import "symbol.h"
#import "class.h"
#import "extensions.h"
#import "objc_runtime.h"

extern id Nu__null;


#define JSBLog	

@implementation NuDefmacro

+ (id) macroWithName:(NSString *)n body:(NuCell *)b
{
    return [[[self alloc] initWithName:n body:b] autorelease];
}

- (void) dealloc
{
    [super dealloc];
}

- (id) initWithName:(NSString *)n body:(NuCell *)b
{
    [super initWithName:n body:b];
    return self;
}

- (NSString *) stringValue
{
    return [NSString stringWithFormat:@"(defmacro %@ %@)", name, [body stringValue]];
}

#if 0
- (id) body:(NuCell *) oldBody withGensymPrefix:(NSString *) prefix symbolTable:(NuSymbolTable *) symbolTable
{
    NuCell *newBody = [[[NuCell alloc] init] autorelease];
    id car = [oldBody car];
    if (car == Nu__null) {
        [newBody setCar:car];
    }
    else if ([car atom]) {
        if (nu_objectIsKindOfClass(car, [NuSymbol class]) && [car isGensym]) {
            [newBody setCar:[symbolTable symbolWithString:[NSString stringWithFormat:@"%@%@", prefix, [car stringValue]]]];
        }
        else if (nu_objectIsKindOfClass(car, [NSString class])) {
            // Here we replace gensyms in interpolated strings.
            // The current solution is workable but fragile;
            // we just blindly replace the gensym names with their expanded names.
            // It would be better to
            // 		1. only replace gensym names in interpolated expressions.
            // 		2. ensure substitutions never overlap.  To do this, I think we should
            //           a. order gensyms by size and do the longest ones first.
            //           b. make the gensym transformation idempotent.
            // That's for another day.
            // For now, I just substitute each gensym name with its expansion.
            //
            #ifdef DARWIN
            NSMutableString *tempString = [NSMutableString stringWithString:car];
            #else
            NSString *tempString = [NSString stringWithString:car];
            #endif
            //NSLog(@"checking %@", tempString);
            NSEnumerator *gensymEnumerator = [gensyms objectEnumerator];
            NuSymbol *gensymSymbol;
            while ((gensymSymbol = [gensymEnumerator nextObject])) {
                //NSLog(@"gensym is %@", [gensymSymbol stringValue]);
                #ifdef DARWIN
                [tempString replaceOccurrencesOfString:[gensymSymbol stringValue]
                    withString:[NSString stringWithFormat:@"%@%@", prefix, [gensymSymbol stringValue]]
                    options:0 range:NSMakeRange(0, [tempString length])];
                #else
                tempString = [tempString stringByReplacingString:[gensymSymbol stringValue] withString:[NSString stringWithFormat:@"%@%@", prefix, [gensymSymbol stringValue]]];
                #endif
            }
            //NSLog(@"setting string to %@", tempString);
            [newBody setCar:tempString];
        }
        else {
            [newBody setCar:car];
        }
    }
    else {
        [newBody setCar:[self body:car withGensymPrefix:prefix symbolTable:symbolTable]];
    }
    id cdr = [oldBody cdr];
    if (cdr && (cdr != Nu__null)) {
        [newBody setCdr:[self body:cdr withGensymPrefix:prefix symbolTable:symbolTable]];
    }
    else {
        [newBody setCdr:cdr];
    }
    return newBody;
}
#endif

#if 0
- (id) expandUnquotes:(id) oldBody withContext:(NSMutableDictionary *) context
{
    NuSymbolTable *symbolTable = [context objectForKey:SYMBOLS_KEY];
    if (oldBody == [NSNull null])
        return oldBody;
    id unquote = [symbolTable symbolWithString:@"unquote"];
    id car = [oldBody car];
    id cdr = [oldBody cdr];
    if ([car atom]) {
        if (car == unquote) {
            return [[cdr car] evalWithContext:context];
        }
        else {
            NuCell *newBody = [[[NuCell alloc] init] autorelease];
            [newBody setCar:car];
            [newBody setCdr:[self expandUnquotes:cdr withContext:context]];
            return newBody;
        }
    }
    else {
        NuCell *newBody = [[[NuCell alloc] init] autorelease];
        [newBody setCar:[self expandUnquotes:car withContext:context]];
        [newBody setCdr:[self expandUnquotes:cdr withContext:context]];
        return newBody;
    }
}
#endif

- (id) expand1:(id)cdr context:(NSMutableDictionary*)calling_context
{
    NuSymbolTable *symbolTable = [calling_context objectForKey:SYMBOLS_KEY];
    //NSLog(@"macro eval %@", [cdr stringValue]);
    // save the current value of margs
    id old_margs = [calling_context objectForKey:[symbolTable symbolWithCString:"margs"]];
    // set the arguments to the special variable "margs"
    [calling_context setPossiblyNullObject:cdr forKey:[symbolTable symbolWithCString:"margs"]];
    // evaluate the body of the block in the calling context (implicit progn)
    id value = Nu__null;

    // if the macro contains gensyms, give them a unique prefix
    int gensymCount = [[self gensyms] count];
    id gensymPrefix = nil;
    if (gensymCount > 0) {
        gensymPrefix = [NSString stringWithFormat:@"g%ld", [NuMath random]];
    }

    id bodyToEvaluate = (gensymCount == 0)
        ? (id)body : [super body:body withGensymPrefix:gensymPrefix symbolTable:symbolTable];

    // uncomment this to get the old (no gensym) behavior.
    JSBLog(@"macrox evaluating: %@", [bodyToEvaluate stringValue]);
    JSBLog(@"macrox context: %@", [calling_context stringValue]);

    id cursor = [self expandUnquotes:bodyToEvaluate withContext:calling_context];
    while (cursor && (cursor != Nu__null)) {
        value = [[cursor car] evalWithContext:calling_context];
        cursor = [cursor cdr];
    }

    // restore the old value of margs
    if (old_margs == nil) {
        [calling_context removeObjectForKey:[symbolTable symbolWithCString:"margs"]];
    }
    else {
        [calling_context setPossiblyNullObject:old_margs forKey:[symbolTable symbolWithCString:"margs"]];
    }

    JSBLog(@"macrox result is %@", value);
    return value;
}





- (id) evalWithArguments:(id)cdr context:(NSMutableDictionary *)calling_context
{
    NuSymbolTable *symbolTable = [calling_context objectForKey:SYMBOLS_KEY];
    //NSLog(@"macro eval %@", [cdr stringValue]);
    // save the current value of margs
    id old_margs = [calling_context objectForKey:[symbolTable symbolWithCString:"margs"]];
    // set the arguments to the special variable "margs"
    [calling_context setPossiblyNullObject:cdr forKey:[symbolTable symbolWithCString:"margs"]];
    // evaluate the body of the block in the calling context (implicit progn)
    id value = Nu__null;

    // if the macro contains gensyms, give them a unique prefix
    int gensymCount = [[self gensyms] count];
    id gensymPrefix = nil;
    if (gensymCount > 0) {
        gensymPrefix = [NSString stringWithFormat:@"g%ld", [NuMath random]];
    }

    id bodyToEvaluate = (gensymCount == 0)
        ? (id)body : [self body:body withGensymPrefix:gensymPrefix symbolTable:symbolTable];

    // uncomment this to get the old (no gensym) behavior.
    JSBLog(@"defmacro evaluating: %@", [bodyToEvaluate stringValue]);
    JSBLog(@"defmacro context: %@", [calling_context stringValue]);

    id cursor = [self expandUnquotes:bodyToEvaluate withContext:calling_context];
    while (cursor && (cursor != Nu__null)) {
		JSBLog(@"defmacro eval cursor(1): %@", [cursor stringValue]);
        value = [[cursor car] evalWithContext:calling_context];
		JSBLog(@"defmacro eval value: %@", [value stringValue]);
        cursor = [cursor cdr];
		//JSBLog(@"defmacro eval cursor(3): %@", [cursor stringValue]);
    }

	// if just macro-expanding, stop here...
	//  ..otherwise eval the outer quote
    id final_value = [value evalWithContext:calling_context];
	JSBLog(@"defmacro eval final_value: %@", [final_value stringValue]);
	
	
    // restore the old value of margs
    if (old_margs == nil) {
        [calling_context removeObjectForKey:[symbolTable symbolWithCString:"margs"]];
    }
    else {
        [calling_context setPossiblyNullObject:old_margs forKey:[symbolTable symbolWithCString:"margs"]];
    }

    // JSBLog(@"result is %@", value);
    return final_value;
}

@end
