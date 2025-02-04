//
//  Communication.mm
//  ObjectiveC SDK
//
//  Created by Yuji on 2015/**/**.
//  Copyright (c) 2015 Star Micronics. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Communication.h"

@implementation Communication

+ (BOOL)sendCommands:(NSData *)commands
                port:(SMPort *)port
   completionHandler:(SendCompletionHandler)completionHandler {
    
    BOOL result = NO;
    NSString *title   = @"";
    NSString *message = @"";
    
    @try {
        while (YES) {
            if (port == nil) {
                title = @"Fail to Open Port";
                break;
            }
            
            StarPrinterStatus_2 printerStatus;
            // Begin checked block to ensure the printer is ready
            [port beginCheckedBlock:&printerStatus :2];
            
            if (printerStatus.offline == SM_TRUE) {
                title   = @"Printer Error";
                message = @"Printer is offline (BeginCheckedBlock)";
                break;
            }
            
            NSDate *startDate = [NSDate date];
            uint32_t total = 0;
            
            // Write the entire command data to the port
            while (total < (uint32_t)commands.length) {
                uint32_t written = [port writePort:(const u_int8_t *)commands.bytes :total :(uint32_t)(commands.length - total)];
                total += written;
                
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 30.0) {  // 30000 ms timeout
                    title   = @"Printer Error";
                    message = @"Write port timed out";
                    break;
                }
            }
            
            if (total < (uint32_t)commands.length) {
                break;
            }
            
            // Set end checked block timeout (30000 ms)
            port.endCheckedBlockTimeoutMillis = 30000;
            [port endCheckedBlock:&printerStatus :2];
            
            if (printerStatus.offline == SM_TRUE) {
                title   = @"Printer Error";
                message = @"Printer is offline (EndCheckedBlock)";
                break;
            }
            
            title   = @"Send Commands";
            message = @"Success";
            result = YES;
            break;
        }
    }
    @catch (PortException *exc) {
        title   = @"Printer Error";
        message = @"Write port timed out (PortException)";
    }
    
    if (completionHandler != nil) {
        completionHandler(result, title, message);
    }
    
    return result;
}

+ (BOOL)sendCommandsDoNotCheckCondition:(NSData *)commands
                               portName:(NSString *)portName
                           portSettings:(NSString *)portSettings
                                timeout:(NSInteger)timeout
                      completionHandler:(SendCompletionHandler)completionHandler {
    
    BOOL result = NO;
    NSString *title   = @"";
    NSString *message = @"";
    NSError *error = nil;
    
    if (timeout > UINT32_MAX) {
        timeout = UINT32_MAX;
    }
    
    SMPort *port = nil;
    
    @try {
        while (YES) {
            port = [SMPort getPort:portName :portSettings :(uint32_t)timeout :&error];
            if (port == nil) {
                title = @"Fail to Open Port";
                break;
            }
            
            // Pause to avoid communication issues with Bluetooth (see Readme)
            NSOperatingSystemVersion version = {11, 0, 0};
            BOOL isOSVer11OrLater = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
            if (isOSVer11OrLater && [portName.uppercaseString hasPrefix:@"BT:"]) {
                [NSThread sleepForTimeInterval:0.2];
            }
            
            StarPrinterStatus_2 printerStatus;
            [port getParsedStatus:&printerStatus :2];
            // (Do not check printerStatus.offline here)
            
            NSDate *startDate = [NSDate date];
            uint32_t total = 0;
            
            while (total < (uint32_t)commands.length) {
                uint32_t written = [port writePort:(unsigned char *)commands.bytes :total :(uint32_t)commands.length - total];
                total += written;
                
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 30.0) {  // 30000 ms timeout
                    title   = @"Printer Error";
                    message = @"Write port timed out";
                    break;
                }
            }
            
            if (total < (uint32_t)commands.length) {
                break;
            }
            
            [port getParsedStatus:&printerStatus :2];
            // (Do not check printerStatus.offline here)
            
            title   = @"Send Commands";
            message = @"Success";
            result = YES;
            break;
        }
    }
    @catch (PortException *exc) {
        title   = @"Printer Error";
        message = @"Write port timed out (PortException)";
    }
    @finally {
        if (port != nil) {
            [SMPort releasePort:port];
            port = nil;
        }
    }
    
    if (completionHandler != nil) {
        completionHandler(result, title, message);
    }
    
    return result;
}

+ (BOOL)parseDoNotCheckCondition:(ISCPParser *)parser
                            port:(SMPort *)port
               completionHandler:(SendCompletionHandler)completionHandler {
    
    BOOL result = NO;
    NSString *title   = @"";
    NSString *message = @"";
    
    NSData *commands = [parser createSendCommands];
    
    @try {
        while (YES) {
            if (port == nil) {
                title = @"Fail to Open Port";
                break;
            }
            
            StarPrinterStatus_2 printerStatus;
            [port getParsedStatus:&printerStatus :2];
            // (Do not check printerStatus.offline)
            
            NSDate *startDate = [NSDate date];
            uint32_t total = 0;
            
            while (total < (uint32_t)commands.length) {
                uint32_t written = [port writePort:(unsigned char *)commands.bytes :total :(uint32_t)commands.length - total];
                total += written;
                
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 30.0) {  // 30000 ms timeout
                    title   = @"Printer Error";
                    message = @"Write port timed out";
                    break;
                }
            }
            
            if (total < (uint32_t)commands.length) {
                break;
            }
            
            startDate = [NSDate date]; // Restart timer for reading
            
            uint8_t buffer[1032]; // 1024 + 8
            int amount = 0;
            
            while (YES) {
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 1.0) {  // 1000 ms timeout
                    title   = @"Printer Error";
                    message = @"Read port timed out";
                    break;
                }
                
                [NSThread sleepForTimeInterval:0.01]; // Short delay
                int readLength = [port readPort:buffer :amount :1024 - amount];
                amount += readLength;
                
                if (parser.completionHandler(buffer, &amount) == StarIoExtParserCompletionResultSuccess) {
                    title   = @"Send Commands";
                    message = @"Success";
                    result = YES;
                    break;
                }
            }
            
            break;
        }
    }
    @catch (PortException *exc) {
        title   = @"Printer Error";
        message = @"Write port timed out (PortException)";
    }
    
    if (completionHandler != nil) {
        completionHandler(result, title, message);
    }
    
    return result;
}

+ (BOOL)sendCommands:(NSData *)commands
            portName:(NSString *)portName
        portSettings:(NSString *)portSettings
             timeout:(NSInteger)timeout
   completionHandler:(SendCompletionHandler)completionHandler {
    
    BOOL result = NO;
    NSString *title   = @"";
    NSString *message = @"";
    NSError *error = nil;
    
    if (timeout > UINT32_MAX) {
        timeout = UINT32_MAX;
    }
    
    SMPort *port = nil;
    
    @try {
        while (YES) {
            port = [SMPort getPort:portName :portSettings :(uint32_t)timeout :&error];
            if (port == nil) {
                title = @"Fail to Open Port";
                break;
            }
            
            // Pause to avoid Bluetooth communication issues (see Readme)
            NSOperatingSystemVersion version = {11, 0, 0};
            BOOL isOSVer11OrLater = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
            if (isOSVer11OrLater && [portName.uppercaseString hasPrefix:@"BT:"]) {
                [NSThread sleepForTimeInterval:0.2];
            }
            
            StarPrinterStatus_2 printerStatus;
            [port beginCheckedBlock:&printerStatus :2];
            if (printerStatus.offline == SM_TRUE) {
                title   = @"Printer Error";
                message = @"Printer is offline (BeginCheckedBlock)";
                break;
            }
            
            NSDate *startDate = [NSDate date];
            uint32_t total = 0;
            
            while (total < (uint32_t)commands.length) {
                uint32_t written = [port writePort:(unsigned char *)commands.bytes :total :(uint32_t)commands.length - total];
                total += written;
                
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 30.0) {  // 30000 ms timeout
                    title   = @"Printer Error";
                    message = @"Write port timed out";
                    break;
                }
            }
            
            if (total < (uint32_t)commands.length) {
                break;
            }
            
            port.endCheckedBlockTimeoutMillis = 30000;
            [port endCheckedBlock:&printerStatus :2];
            if (printerStatus.offline == SM_TRUE) {
                title   = @"Printer Error";
                message = @"Printer is offline (EndCheckedBlock)";
                break;
            }
            
            title   = @"Send Commands";
            message = @"Success";
            result = YES;
            break;
        }
    }
    @catch (PortException *exc) {
        title   = @"Printer Error";
        message = @"Write port timed out (PortException)";
    }
    @finally {
        if (port != nil) {
            [SMPort releasePort:port];
            port = nil;
        }
    }
    
    if (completionHandler != nil) {
        completionHandler(result, title, message);
    }
    
    return result;
}

+ (BOOL)disconnectBluetooth:(NSString *)modelName
                   portName:(NSString *)portName
               portSettings:(NSString *)portSettings
                    timeout:(NSInteger)timeout
          completionHandler:(SendCompletionHandler)completionHandler {
    
    BOOL result = NO;
    NSString *title   = @"";
    NSString *message = @"";
    NSError *error = nil;
    
    SMPort *port = nil;
    
    @try {
        while (YES) {
            port = [SMPort getPort:portName :portSettings :(uint32_t)timeout :&error];
            if (port == nil) {
                title = @"Fail to Open Port";
                break;
            }
            
            // Pause to avoid Bluetooth communication issues (see Readme)
            NSOperatingSystemVersion version = {11, 0, 0};
            BOOL isOSVer11OrLater = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
            if (isOSVer11OrLater && [portName.uppercaseString hasPrefix:@"BT:"]) {
                [NSThread sleepForTimeInterval:0.2];
            }
            
            if ([modelName hasPrefix:@"TSP143IIIBI"]) {
                // This command is for TSP143IIIBI only
                unsigned char commandBytes[] = {0x1b, 0x1c, 0x26, 0x49};
                StarPrinterStatus_2 printerStatus;
                
                [port beginCheckedBlock:&printerStatus :2];
                if (printerStatus.offline == SM_TRUE) {
                    title   = @"Printer Error";
                    message = @"Printer is offline (BeginCheckedBlock)";
                    break;
                }
                
                NSDate *startDate = [NSDate date];
                uint32_t total = 0;
                
                while (total < sizeof(commandBytes)) {
                    uint32_t written = [port writePort:commandBytes :total :sizeof(commandBytes) - total];
                    total += written;
                    
                    if ([[NSDate date] timeIntervalSinceDate:startDate] >= 30.0) {  // 30000 ms timeout
                        title   = @"Printer Error";
                        message = @"Write port timed out";
                        break;
                    }
                }
                
                if (total < sizeof(commandBytes)) {
                    break;
                }
                
                // The endCheckedBlock code is commented out for TSP143IIIBI
            }
            else {
                if ([port disconnect] == NO) {
                    title   = @"Fail to Disconnect";
                    message = @"Note: Portable Printers are not supported.";
                    break;
                }
            }
            
            title   = @"Success";
            message = @"";
            result = YES;
            break;
        }
    }
    @catch (PortException *exc) {
        title   = @"Printer Error";
        message = @"Write port timed out (PortException)";
    }
    @finally {
        if (port != nil) {
            [SMPort releasePort:port];
            port = nil;
        }
    }
    
    if (completionHandler != nil) {
        completionHandler(result, title, message);
    }
    
    return result;
}

+ (BOOL)confirmSerialNumber:(NSString *)portName
               portSettings:(NSString *)portSettings
                    timeout:(NSInteger)timeout
          completionHandler:(SendCompletionHandler)completionHandler {
    
    BOOL result = NO;
    NSString *title   = @"";
    NSString *message = @"";
    NSError *error = nil;
    
    if (timeout > UINT32_MAX) {
        timeout = UINT32_MAX;
    }
    
    SMPort *port = nil;
    
    @try {
        while (YES) {
            port = [SMPort getPort:portName :portSettings :(uint32_t)timeout :&error];
            if (port == nil) {
                title = @"Fail to Open Port";
                break;
            }
            
            // Pause to avoid Bluetooth communication issues (see Readme)
            NSOperatingSystemVersion version = {11, 0, 0};
            BOOL isOSVer11OrLater = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
            if (isOSVer11OrLater && [portName.uppercaseString hasPrefix:@"BT:"]) {
                [NSThread sleepForTimeInterval:0.2];
            }
            
            StarPrinterStatus_2 printerStatus;
            [port getParsedStatus:&printerStatus :2];
            // (Do not check printerStatus.offline)
            
            NSDate *startDate = [NSDate date];
            uint32_t total = 0;
            // The command to request serial number information
            unsigned char commandBytes[] = {0x1b, 0x1d, ')', 'I', 0x01, 0x00, 49};
            
            while (total < sizeof(commandBytes)) {
                uint32_t written = [port writePort:commandBytes :total :sizeof(commandBytes) - total];
                total += written;
                
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 3.0) {  // 3000 ms timeout
                    title   = @"Printer Error";
                    message = @"Write port timed out";
                    break;
                }
            }
            
            if (total < sizeof(commandBytes)) {
                break;
            }
            
            NSString *information = nil;
            uint8_t readBuffer[1032]; // 1024 + 8
            int amountRead = 0;
            
            while (YES) {
                if ([[NSDate date] timeIntervalSinceDate:startDate] >= 3.0) {  // 3000 ms timeout
                    title   = @"Printer Error";
                    message = @"Cannot receive information";
                    break;
                }
                
                @try {
                    int readLength = [port readPort:readBuffer :0 :1024 - amountRead];
                    if (readLength <= 0) {
                        continue;
                    }
                    amountRead += readLength;
                }
                @catch (NSException *exception) {
                    @throw exception;
                }
                
                if (amountRead >= 2) {
                    for (int i = 0; i <= amountRead - 2; i++) {
                        if (readBuffer[i] == 0x0a && readBuffer[i+1] == 0x00) {
                            // Look for the tag in the response buffer
                            for (int j = 0; j <= amountRead - 9; j++) {
                                if (readBuffer[j] == 0x1b &&
                                    readBuffer[j+1] == 0x1d &&
                                    readBuffer[j+2] == ')' &&
                                    readBuffer[j+3] == 'I' &&
                                    readBuffer[j+6] == 49) {
                                    
                                    information = [NSString stringWithCString:(const char *)&readBuffer[j+7] encoding:NSASCIIStringEncoding];
                                    result = YES;
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }
                
                if (result == YES) {
                    break;
                }
            }
            
            if (result == NO) {
                break;
            }
            
            result = NO;
            NSRange range = [information rangeOfString:@"PrSrN="];
            if (range.location == NSNotFound) {
                title   = @"Printer Error";
                message = @"Cannot receive tag";
                break;
            }
            
            NSString *work = [information substringFromIndex:range.location + range.length];
            range = [work rangeOfString:@","];
            if (range.location != NSNotFound) {
                work = [work substringToIndex:range.location];
            }
            
            title   = @"Serial Number";
            message = work;
            result = YES;
            break;
        }
    }
    @catch (PortException *exception) {
        title   = @"Printer Error";
        message = @"Write port timed out (PortException)";
    }
    @finally {
        if (port != nil) {
            [SMPort releasePort:port];
            port = nil;
        }
    }
    
    if (completionHandler != nil) {
        completionHandler(result, title, message);
    }
    
    return result;
}

+ (void)connectBluetooth:(SendCompletionHandler)completionHandler {
    [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error) {
        BOOL result;
        NSString *title   = @"";
        NSString *message = @"";
        
        if (error != nil) {
            NSLog(@"Error: %@", error.description);
            switch (error.code) {
                case EABluetoothAccessoryPickerAlreadyConnected:
                    title   = @"Success";
                    message = @"";
                    result = YES;
                    break;
                case EABluetoothAccessoryPickerResultCancelled:
                case EABluetoothAccessoryPickerResultFailed:
                    title   = nil;
                    message = nil;
                    result = NO;
                    break;
                default:
                    title   = @"Fail to Connect";
                    message = @"";
                    result = NO;
                    break;
            }
        }
        else {
            title   = @"Success";
            message = @"";
            result = YES;
        }
        
        if (completionHandler != nil) {
            completionHandler(result, title, message);
        }
    }];
}

@end
