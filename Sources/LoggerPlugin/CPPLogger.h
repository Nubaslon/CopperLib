//
//  CPPLogger.h
//  Pods
//
//  Created by ANTROPOV Evgeny on 21.02.2022.
//

#ifndef CPPLogger_h
#define CPPLogger_h


#define CPPLoggerLogError(fmt, ...) [CPPLogger logErrorWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogCritical(fmt, ...) [CPPLogger logCriticalWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogDebug(fmt, ...) [CPPLogger logDebugWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogInfo(fmt, ...) [CPPLogger logInfoWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogNotice(fmt, ...) [CPPLogger logNoticeWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogTrace(fmt, ...) [CPPLogger logTraceWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogWarning(fmt, ...) [CPPLogger logWarningWithMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__] metadata:nil file:__FILE__ function:__PRETTY_FUNCTION__ line:__LINE__];

#define CPPLoggerLogWithMetadataError(message, metaObject) [CPPLogger logErrorWithMessage:message metadata:metaObject ffile:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogWithMetadataCritical(message, metaObject) [CPPLogger logCriticalWithMessage:message metadata:metaObject file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogWithMetadataDebug(message, metaObject) [CPPLogger logDebugWithMessage:message metadata:metaObject file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogWithMetadataInfo(message, metaObject) [CPPLogger logInfoWithMessage:message metadata:metaObject file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]
#define CPPLoggerLogWithMetadataNotice(message, metaObject) [CPPLogger logNoticeWithMessage:message metadata:metaObject file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogWithMetadataTrace(message, metaObject) [CPPLogger logTraceWithMessage:message metadata:metaObject file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];
#define CPPLoggerLogWithMetadataWarning(message, metaObject) [CPPLogger logWarningWithMessage:message metadata:metaObject file:[NSString stringWithUTF8String:__FILE__] function:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] line:__LINE__];

#endif /* CPPLogger_h */
