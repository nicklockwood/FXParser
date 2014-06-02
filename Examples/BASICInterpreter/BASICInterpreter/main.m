//
//  main.m
//  BASICInterpreter
//
//  Created by Nick Lockwood on 31/05/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FXParser.h"

// the BASICGrammar.h file will be created at build time using the following shell script

// cd "${SRCROOT}/BASICInterpreter/"
// /usr/bin/xxd -i "BASICGrammar.txt" "BASICGrammar.h"

// which converts the BASICGrammar.txt file into a header containing the following:

// unsigned char BASICGrammar_txt[] = {...};
// unsigned int BASICGrammar_txt_len = ...;

#import "BASICGrammar.h"


@interface Variable : NSObject

+ (void)resetVariables;
+ (instancetype)variableWithName:(NSString *)name;

@property (nonatomic, strong) id value;

@end


@implementation Variable
{
    NSString *_name;
}

static NSMutableDictionary *storage = nil;

+ (void)initialize
{
    storage = [NSMutableDictionary dictionary];
}

+ (void)resetVariables
{
    for (Variable *variable in [storage allValues])
    {
        variable.value = nil;
    }
}

+ (instancetype)variableWithName:(NSString *)name
{
    Variable *variable = storage[name];
    if (!variable)
    {
        variable = [[self alloc] init];
        variable->_name = name;
        storage[name] = variable;
    }
    return variable;
}

- (id)value
{
    return _value ?: @"[undefined]";
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<Variable name = %@; value = %@>", self->_name, self.value];
}

@end


@interface Expression : NSObject

+ (instancetype)expressionWithBlock:(id (^)(void))block;
- (id)value;

@end


@implementation Expression
{
    id (^_block)(void);
}

+ (instancetype)expressionWithBlock:(id (^)(void))block
{
    Expression *expression = [[self alloc] init];
    expression->_block = block;
    return expression;
}

- (id)value
{
    id value = self;
    while ([value isKindOfClass:[Expression class]])
    {
        value = ((Expression *)value)->_block();
    }
    if ([value isKindOfClass:[Variable class]])
    {
        value = ((Variable *)value).value;
    }
    return value;
}

@end


@interface Statement : NSObject

+ (instancetype)statementWithBlock:(void (^)(void))block;

@property (nonatomic, readonly) void (^block)(void);

@end


@implementation Statement

+ (instancetype)statementWithBlock:(void (^)(void))block
{
    Statement *statement = [[self alloc] init];
    statement->_block = block;
    return statement;
}
                                    
@end


int main(int argc, const char * aargv[])
{
    @autoreleasepool
    {
        //program
        __block FXParser *commandInterpreter = nil;
        __block FXParser *instructionInterpreter = nil;
        __block NSMutableDictionary *linesByNumber = [NSMutableDictionary dictionary];
        __block NSArray *lineNumbers = nil;
        __block NSInteger programCounter = 0;
        __block BOOL programRunning = NO;
        
        //define interpreter callbacks
        FXParser *grammarParser = [FXParser grammarParserWithTransformer:^FXParser *(NSString *name, FXParser *parser) {
            
            if ([name isEqualToString:@"integer"])
            {
                return [parser withValueForKeyPath:@"integerValue"];
            }
            if ([name isEqualToString:@"decimal"])
            {
                return [parser withValueForKeyPath:@"doubleValue"];
            }
            else if ([name isEqualToString:@"string"])
            {
                return [parser asString];
            }
            else if ([name isEqualToString:@"identifier"])
            {
                return [parser withTransformer:^id(NSString *name) {
                    
                    return [Variable variableWithName:name];
                }];
            }
            else if ([name isEqualToString:@"expression"])
            {
                return [parser withTransformer:^id (id value) {
                    
                    return [Expression expressionWithBlock:^id {
                        
                        if ([value isKindOfClass:[NSArray class]])
                        {
                            id a = value[0];
                            if ([a isKindOfClass:[Variable class]])
                            {
                                a = ((Variable *)a).value;
                            }
                            id b = [(Expression *)value[1] value];
                            if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]])
                            {
                                return @([a doubleValue] + [b doubleValue]);
                            }
                            else
                            {
                                return [[a description] stringByAppendingString:[b description]];
                            }
                        }
                        return value;
                    }];
                }];
            }
            else if ([name isEqualToString:@"assignment"])
            {
                return [parser withTransformer:^id(NSArray *values) {
                    
                    return [Statement statementWithBlock:^{
                        
                        ((Variable *)values[0]).value = [(Expression *)values[1] value];
                    }];
                }];
            }
            else if ([name isEqualToString:@"print"])
            {
                return [parser withTransformer:^id(Expression *expression) {
                    
                    return [Statement statementWithBlock:^{
                        
                        printf("%s", [[[expression value] description] UTF8String]);
                    }];
                }];
            }
            else if ([name isEqualToString:@"println"])
            {
                return [parser withTransformer:^id(Expression *expression) {
                    
                    return [Statement statementWithBlock:^{
                        
                        printf("%s\n", [[[expression value] description] UTF8String]);
                    }];
                }];
            }
            else if ([name isEqualToString:@"input"])
            {
                return [parser withTransformer:^id(Variable *variable) {
                    
                    return [Statement statementWithBlock:^{
                        
                        size_t length;
                        char *line = fgetln(stdin, &length);
                        NSString *lineString = [[NSString alloc] initWithBytes:line length:length encoding:NSUTF8StringEncoding];
                        variable.value = [lineString stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    }];
                }];
            }
            else if ([name isEqualToString:@"goto"])
            {
                return [parser withTransformer:^id(NSNumber *number) {
                    
                    return [Statement statementWithBlock:^{
                        
                        programCounter = [lineNumbers indexOfObject:number];
                        if (programCounter == NSNotFound)
                        {
                            NSLog(@"Line number %@ not found. Program terminated.", number);
                            programRunning = NO;
                        }
                    }];
                }];
            }
            else if ([name isEqualToString:@"line"])
            {
                return [parser withTransformer:^id(NSArray *parts) {
                    
                    if ([parts isKindOfClass:[Statement class]])
                    {
                        //immediate mode instruction
                        return parts;
                    }
                    else if (parts)
                    {
                        //numbered line
                        NSString *instruction = parts[1];
                        FXParserResult *result = [instructionInterpreter parse:instruction];
                        if (!result.success)
                        {
                            NSLog(@"Syntax error. Expected: %@", result.expected);
                        }
                        else
                        {
                            linesByNumber[parts[0]] = [instruction stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        }
                    }
                    return nil;
                }];
            }
            else if ([name isEqualToString:@"run"])
            {
                return [parser withTransformer:^id(__unused id value) {
                
                    return [Statement statementWithBlock:^{
                    
                        //run program
                        programCounter = 0;
                        programRunning = YES;
                        lineNumbers = [[linesByNumber allKeys] sortedArrayUsingSelector:@selector(compare:)];
                        while (programRunning && programCounter < [lineNumbers count])
                        {
                            NSNumber *lineNumber = lineNumbers[programCounter ++];
                            NSString *instruction = linesByNumber[lineNumber];
                            FXParserResult *result = [instructionInterpreter parse:instruction];
                            Statement *statement = result.value;
                            statement.block();
                        }
                    }];
                }];
            }
            else if ([name isEqualToString:@"new"])
            {
                return [parser withTransformer:^id(__unused id value) {
                    
                    return [Statement statementWithBlock:^{
                    
                        //clear program
                        [linesByNumber removeAllObjects];
                    }];
                }];
            }
            else if ([name isEqualToString:@"renumber"])
            {
                return [parser withTransformer:^id(__unused id value) {
                    
                    return [Statement statementWithBlock:^{
                        
                        //renumber program
                        NSMutableDictionary *newLinesByNumber = [NSMutableDictionary dictionary];
                        lineNumbers = [[linesByNumber allKeys] sortedArrayUsingSelector:@selector(compare:)];
                        NSInteger newNumber = 10;
                        for (NSNumber *oldNumber in lineNumbers)
                        {
                            newLinesByNumber[@(newNumber)] = linesByNumber[oldNumber];
                            newNumber += 10;
                        }
                        [linesByNumber setDictionary:newLinesByNumber];
                    }];
                }];
            }
            else if ([name isEqualToString:@"list"])
            {
                return [parser withTransformer:^id(__unused id value) {
                    
                    return [Statement statementWithBlock:^{
                        
                        //list program
                        lineNumbers = [[linesByNumber allKeys] sortedArrayUsingSelector:@selector(compare:)];
                        for (NSNumber *number in lineNumbers)
                        {
                            printf("%i %s\n", [number intValue], [linesByNumber[number] UTF8String]);
                        }
                    }];
                }];
            }
            else if ([name isEqualToString:@"delete"])
            {
                return [parser withTransformer:^id(NSNumber *lineNumber) {
                    
                    return [Statement statementWithBlock:^{
                        
                        //delete line
                        [linesByNumber removeObjectForKey:lineNumber];
                    }];
                }];
            }
            else if ([name isEqualToString:@"program"])
            {
                return [parser withTransformer:^id(NSArray *statements) {
                    
                    [Variable resetVariables];
                    for (Statement *statement in statements)
                    {
                        statement.block();
                    }
                    return nil;
                }];
            }
            
            return parser;
        }];
        
        //load grammar data (encoded in the generated BASICGrammar.h file)
        NSString *grammarString = [[NSString alloc] initWithBytes:BASICGrammar_txt length:BASICGrammar_txt_len encoding:NSUTF8StringEncoding];

        //parse grammar
        FXParserResult *grammarResult = [grammarParser parse:grammarString];
        if (!grammarResult.success)
        {
            NSLog(@"Failed to parse grammar. Expected: %@", grammarResult.expected);
        }
        
        //get command intepreter
        //this interprets a single line of code
        //you can parse an entire program using grammarResult.value[@"program"] instead
        commandInterpreter = grammarResult.value[@"line"];
        instructionInterpreter = grammarResult.value[@"instruction"];

        //print intro
        printf("BASIC Interpreter\n\n");
        
        //start console
        while (true)
        {
            //print prompt
            printf("> ");
            
            //get command
            size_t length;
            char *line = fgetln(stdin, &length);
            NSString *command = [[NSString alloc] initWithBytes:line length:length encoding:NSUTF8StringEncoding];
            
            //strip invisible characters (e.g. backspace, arrow)
            command = [command stringByReplacingOccurrencesOfString:@"[^a-zA-Z0-9 \\t_!@£$%^&*()+=\\[\\]{};:\"'<,>\\.?/\\\\-]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [command length])];
            
            //ignore blank lines
            if ([[command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length])
            {
                //execute command
                FXParserResult *result = [commandInterpreter parse:command];
                if (!result.success)
                {
                    NSLog(@"Syntax error. Expected: %@", result.expected);
                }
                else if (result.value)
                {
                    //execute command
                    ((Statement *)result.value).block();
                }
            }
        }
    }
    return 0;
}

