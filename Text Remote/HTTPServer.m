#import "HTTPServer.h"


@implementation HTTPServer

-(RootViewController*)rvc{
    return  rootViewController;
}

-(void)setRootViewController:(RootViewController*)rvc{
    rootViewController = rvc;
}


- (id)init {
    connClass = [HTTPConnection self];
    
  javascript=@"";
    ABAddressBookRef addressBook = ABAddressBookCreate();
    
    NSArray *addresses = (NSArray *) ABAddressBookCopyArrayOfAllPeople(addressBook);
    int counter =0;
    for (int i = 0; i < [addresses count]; i++) {
        ABRecordRef record = [addresses objectAtIndex:i];
        NSString *firstName = (NSString *)ABRecordCopyValue(record, kABPersonFirstNameProperty);
        NSString *lastName = (NSString *)ABRecordCopyValue(record, kABPersonLastNameProperty);


        ABMultiValueRef * phoneNumbers =(ABMultiValueRef *)ABRecordCopyValue(record, kABPersonPhoneProperty);
        
        
        

            for(int i = 0; i < ABMultiValueGetCount(phoneNumbers); i++)
            {
                NSString *label = (NSString*)ABMultiValueCopyLabelAtIndex(phoneNumbers, i);
                
                if([label isEqualToString:@"_$!<Mobile>!$_"]){
                    label = @"Mobile";
                }else if([label isEqualToString:@"_$!<Work>!$_"]){
                    label=@"Work";
                }else if([label isEqualToString:@"_$!<Home>!$_"]){
                    label=@"Home";
                }else{
                    label =@"";
                }
                
                
                NSString *value = (NSString*)ABMultiValueCopyValueAtIndex(phoneNumbers, i);
                NSString *value2 = @"";
                for(int i = 0 ; i < [value length]; i++){
                    if([value characterAtIndex:i] >= '0' && [value characterAtIndex:i] <= '9'){
                    value2 = [value2 stringByAppendingFormat:@"%c",[value characterAtIndex:i]];
                    }
                }
                
                NSString * fullName;
                if(firstName==nil && lastName==nil){
                    fullName= [NSString stringWithFormat:@""];
                }else if(lastName==nil){
                    fullName= [NSString stringWithFormat:@"%@", firstName];
                }else if(firstName==nil){
                    fullName= [NSString stringWithFormat:@"%@", lastName];
                }else{
                  fullName= [NSString stringWithFormat:@"%@ %@", firstName, lastName];
                }
               
                
                
                
               javascript=  [javascript stringByAppendingFormat:@"\nsuggestions[%d]=\"%@\";\nsuggestionNames[%d]=\"%@\";\nsuggestionTypes[%d]=\"%@\"",counter, value2,counter ,fullName ,counter, label];
                counter++;
                
            }
  
        
        
   
    }
    
    [javascript retain];
    
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (Class)connectionClass {
    return connClass;
}

- (void)setConnectionClass:(Class)value {
    connClass = value;
}

- (NSURL *)documentRoot {
    return docRoot;
}

- (void)setDocumentRoot:(NSURL *)value {
    if (docRoot != value) {
        [docRoot release];
        docRoot = [value copy];
    }
}

// Converts the TCPServer delegate notification into the HTTPServer delegate method.
- (void)handleNewConnectionFromAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    HTTPConnection *connection = [[connClass alloc] initWithPeerAddress:addr inputStream:istr outputStream:ostr forServer:self];
    [connection setDelegate:[self delegate]];
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(HTTPServer:didMakeNewConnection:)]) { 
        [[self delegate] HTTPServer:self didMakeNewConnection:connection];
    }
    // The connection at this point is turned loose to exist on its
    // own, and not released or autoreleased.  Alternatively, the
    // HTTPServer could keep a list of connections, and HTTPConnection
    // would have to tell the server to delete one at invalidation
    // time.  This would perhaps be more correct and ensure no
    // spurious leaks get reported by the tools, but HTTPServer
    // has nothing further it wants to do with the HTTPConnections,
    // and would just be "owning" the connections for form.
}

@synthesize javascript;
@end


@implementation HTTPConnection

- (id)init {
    
    
    
    
    [self dealloc];
    
    
    
    
    return nil;
}

- (id)initWithPeerAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr forServer:(HTTPServer *)serv {
    peerAddress = [addr copy];
    server = serv;
    istream = [istr retain];
    ostream = [ostr retain];
    [istream setDelegate:self];
    [ostream setDelegate:self];
    [istream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:(id)kCFRunLoopCommonModes];
    [ostream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:(id)kCFRunLoopCommonModes];
    [istream open];
    [ostream open];
    isValid = YES;
    return self;
}

- (void)dealloc {
    [self invalidate];
    [peerAddress release];
    [super dealloc];
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)value {
    delegate = value;
}

- (NSData *)peerAddress {
    return peerAddress;
}

- (HTTPServer *)server {
    return server;
}

- (HTTPServerRequest *)nextRequest {
    unsigned idx, cnt = requests ? [requests count] : 0;
    for (idx = 0; idx < cnt; idx++) {
        id obj = [requests objectAtIndex:idx];
        if ([obj response] == nil) {
            return obj;
        }
    }
    return nil;
}

- (BOOL)isValid {
    return isValid;
}

- (void)invalidate {
    if (isValid) {
        isValid = NO;
        [istream close];
        [ostream close];
        [istream release];
        [ostream release];
        istream = nil;
        ostream = nil;
        [ibuffer release];
        [obuffer release];
        ibuffer = nil;
        obuffer = nil;
        [requests release];
        requests = nil;
        [self release];
        // This last line removes the implicit retain the HTTPConnection
        // has on itself, given by the HTTPServer when it abandoned the
        // new connection.
    }
}

// YES return means that a complete request was parsed, and the caller
// should call again as the buffered bytes may have another complete
// request available.
- (BOOL)processIncomingBytes {
    CFHTTPMessageRef working = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
    CFHTTPMessageAppendBytes(working, [ibuffer bytes], [ibuffer length]);
    
    // This "try and possibly succeed" approach is potentially expensive
    // (lots of bytes being copied around), but the only API available for
    // the server to use, short of doing the parsing itself.
    
    // HTTPConnection does not handle the chunked transfer encoding
    // described in the HTTP spec.  And if there is no Content-Length
    // header, then the request is the remainder of the stream bytes.
    
    if (CFHTTPMessageIsHeaderComplete(working)) {
        NSString *contentLengthValue = [(NSString *)CFHTTPMessageCopyHeaderFieldValue(working, (CFStringRef)@"Content-Length") autorelease];
        
        unsigned contentLength = contentLengthValue ? [contentLengthValue intValue] : 0;
        NSData *body = [(NSData *)CFHTTPMessageCopyBody(working) autorelease];
        unsigned bodyLength = [body length];
        if (contentLength <= bodyLength) {
            NSData *newBody = [NSData dataWithBytes:[body bytes] length:contentLength];
            [ibuffer setLength:0];
            [ibuffer appendBytes:([body bytes] + contentLength) length:(bodyLength - contentLength)];
            CFHTTPMessageSetBody(working, (CFDataRef)newBody);
        } else {
            CFRelease(working);
            return NO;
        }
    } else {
        return NO;
    }
    
    HTTPServerRequest *request = [[HTTPServerRequest alloc] initWithRequest:working connection:self];
    if (!requests) {
        requests = [[NSMutableArray alloc] init];
    }
    [requests addObject:request];
    if (delegate && [delegate respondsToSelector:@selector(HTTPConnection:didReceiveRequest:)]) { 
        [delegate HTTPConnection:self didReceiveRequest:request];
    } else {
        [self performDefaultRequestHandling:request];
    }
    
    CFRelease(working);
    return YES;
}

- (void)processOutgoingBytes {
    // The HTTP headers, then the body if any, then the response stream get
    // written out, in that order.  The Content-Length: header is assumed to 
    // be properly set in the response.  Outgoing responses are processed in 
    // the order the requests were received (required by HTTP).
    
    // Write as many bytes as possible, from buffered bytes, response
    // headers and body, and response stream.

    if (![ostream hasSpaceAvailable]) {
        return;
    }

    unsigned olen = [obuffer length];
    if (0 < olen) {
        int writ = [ostream write:[obuffer bytes] maxLength:olen];
        // buffer any unwritten bytes for later writing
        if (writ < olen) {
            memmove([obuffer mutableBytes], [obuffer mutableBytes] + writ, olen - writ);
            [obuffer setLength:olen - writ];
            return;
        }
        [obuffer setLength:0];
    }

    unsigned cnt = requests ? [requests count] : 0;
    HTTPServerRequest *req = (0 < cnt) ? [requests objectAtIndex:0] : nil;

    CFHTTPMessageRef cfresp = req ? [req response] : NULL;
    if (!cfresp) return;
    
    if (!obuffer) {
        obuffer = [[NSMutableData alloc] init];
    }

    if (!firstResponseDone) {
        firstResponseDone = YES;
        NSData *serialized = [(NSData *)CFHTTPMessageCopySerializedMessage(cfresp) autorelease];
        unsigned olen = [serialized length];
        if (0 < olen) {
            int writ = [ostream write:[serialized bytes] maxLength:olen];
            if (writ < olen) {
                // buffer any unwritten bytes for later writing
                [obuffer setLength:(olen - writ)];
                memmove([obuffer mutableBytes], [serialized bytes] + writ, olen - writ);
                return;
            }
        }
    }

    NSInputStream *respStream = [req responseBodyStream];
    if (respStream) {
        if ([respStream streamStatus] == NSStreamStatusNotOpen) {
            [respStream open];
        }
        // read some bytes from the stream into our local buffer
        [obuffer setLength:16 * 1024];
        int read = [respStream read:[obuffer mutableBytes] maxLength:[obuffer length]];
        [obuffer setLength:read];
    }

    if (0 == [obuffer length]) {
        // When we get to this point with an empty buffer, then the 
        // processing of the response is done. If the input stream
        // is closed or at EOF, then no more requests are coming in.
        if (delegate && [delegate respondsToSelector:@selector(HTTPConnection:didSendResponse:)]) { 
            [delegate HTTPConnection:self didSendResponse:req];
        }
        [requests removeObjectAtIndex:0];
        firstResponseDone = NO;
        if ([istream streamStatus] == NSStreamStatusAtEnd && [requests count] == 0) {
            [self invalidate];
        }
        return;
    }
    
    olen = [obuffer length];
    if (0 < olen) {
        int writ = [ostream write:[obuffer bytes] maxLength:olen];
        // buffer any unwritten bytes for later writing
        if (writ < olen) {
            memmove([obuffer mutableBytes], [obuffer mutableBytes] + writ, olen - writ);
        }
        [obuffer setLength:olen - writ];
    }
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent {
    switch(streamEvent) {
    case NSStreamEventHasBytesAvailable:;
        uint8_t buf[16 * 1024];
        uint8_t *buffer = NULL;
        unsigned int len = 0;
        if (![istream getBuffer:&buffer length:&len]) {
            int amount = [istream read:buf maxLength:sizeof(buf)];
            buffer = buf;
            len = amount;
        }
        if (0 < len) {
            if (!ibuffer) {
                ibuffer = [[NSMutableData alloc] init];
            }
            [ibuffer appendBytes:buffer length:len];
        }
        do {} while ([self processIncomingBytes]);
        break;
    case NSStreamEventHasSpaceAvailable:;
        [self processOutgoingBytes];
        break;
    case NSStreamEventEndEncountered:;
        [self processIncomingBytes];
        if (stream == ostream) {
            // When the output stream is closed, no more writing will succeed and
            // will abandon the processing of any pending requests and further
            // incoming bytes.
            [self invalidate];
        }
        break;
    case NSStreamEventErrorOccurred:;
        NSLog(@"HTTPServer stream error: %@", [stream streamError]);
        break;
    default:
        break;
    }
}

-(NSArray*)decodePost:(NSString*)input{
    NSArray * a = [input componentsSeparatedByString:@"\n"];
    NSMutableArray  * c=[[NSMutableArray alloc ] init];
    if([a count] > 3){
    [c addObject:[a objectAtIndex:3]];
    NSString * b = @"";
    if([a count] > 7){
        for(int i = 7; i < [a count]-2;i++){
            if(i!=7){
                b= [b stringByAppendingFormat:@"\n"];
            }
            b = [b stringByAppendingString:[a objectAtIndex:i]];
        }
    }
    [c addObject:b];
    }
    return c;
}


- (void)performDefaultRequestHandling:(HTTPServerRequest *)mess {
    CFHTTPMessageRef request = [mess request];
    NSString *vers = [(id)CFHTTPMessageCopyVersion(request) autorelease];
    if (!vers || ![vers isEqual:(id)kCFHTTPVersion1_1]) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 505, NULL, (CFStringRef)vers); // Version Not Supported
        [mess setResponse:response];
        CFRelease(response);
        return;
    }
    NSString *method = [(id)CFHTTPMessageCopyRequestMethod(request) autorelease];
    if (!method) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1); // Bad Request
        [mess setResponse:response];
        CFRelease(response);
        return;
    }
    
    BOOL authenticated = NO;
    
    authenticated=![[[[mess connection] server] rvc] securityEnabled];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:NSYearCalendarUnit fromDate:[NSDate date]];
    NSInteger year = [components year];
    NSString * authString = [NSString stringWithFormat:@"authenticated=yes;Expires=Wed, 13-Jan-%d 22:23:01 GMT;", year + 1] ;
    

    if([(NSString*)CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)@"Cookie") isEqualToString:authString]){
        authenticated=YES;
    }
    
    if([method isEqual:@"POST"] && authenticated){

        NSData * inputData =(NSData*)CFHTTPMessageCopyBody(request);
        NSString * codeString = [[NSString alloc] initWithData:inputData encoding:NSASCIIStringEncoding];
        
        NSArray * a =   [self decodePost:codeString];
        if([a count] >= 2){
            [[[[mess connection]server] rvc] sendMessage:[a objectAtIndex:0] andMessage:[a objectAtIndex:1]];
        }
    }
    
    if([method isEqual:@"POST"]){
        NSData * inputData =(NSData*)CFHTTPMessageCopyBody(request);
        NSString * codeString = [[NSString alloc] initWithData:inputData encoding:NSASCIIStringEncoding];
        NSArray * stuff = [codeString componentsSeparatedByString:@"&"];
        int * authenticate = [[[[mess connection] server] rvc] getPointerToCode];
        if([stuff count] == 4){
            for(int i = 0 ; i <  4; i++){
                NSString * current = [stuff objectAtIndex:i];
                current = [current stringByReplacingOccurrencesOfString:@"one=" withString:@""];
                current = [current stringByReplacingOccurrencesOfString:@"two=" withString:@""];
                
                current = [current stringByReplacingOccurrencesOfString:@"three=" withString:@""];
                
                current = [current stringByReplacingOccurrencesOfString:@"four=" withString:@""];
                
                if(authenticate[i] != [current intValue]){
                    break;
                }
                if(i == 3){
                    authenticated = YES;
                }
            }
        }
    }
    
    if ([method isEqual:@"GET"] || [method isEqual:@"HEAD"] || [method isEqual:@"POST"]) {
        NSURL *uri = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];

        NSData *data  =nil;
        if([[uri pathComponents] lastObject] != nil && [[[uri pathComponents] lastObject] isEqualToString:@"lock.png"] ){
             data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"lock" withExtension:@"png"]];
        }else{
            if(!authenticated){
                data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"]];
            }else{
                data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"send" withExtension:@"html"]];
                NSString * stuffString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                stuffString = [stuffString stringByReplacingOccurrencesOfString:@"JAVASCRIPTSTUFF" withString:[[[mess connection] server] javascript]];
                data =[NSData dataWithBytes:[stuffString UTF8String] length:[stuffString length]];
                [stuffString release];
            }
        }
        
        if (!data) {
            CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 404, NULL, kCFHTTPVersion1_1); // Not Found
            [mess setResponse:response];
            CFRelease(response);
            return;
        }

        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1); // OK
           CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%d", [data length]]);
        
        if([[uri pathComponents] lastObject] != nil && [[[uri pathComponents] lastObject] isEqualToString:@"lock.png"] ){
             CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/png");

        }else{
           CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"text/html");
         
        }
        if(authenticated){
            CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Set-Cookie", (CFStringRef)authString);
        }
        
        if ([method isEqual:@"GET"] || [method isEqual:@"POST"]) {
            CFHTTPMessageSetBody(response, (CFDataRef)data);
        }
        [mess setResponse:response];
        CFRelease(response);
        return;
    }

    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 405, NULL, kCFHTTPVersion1_1); // Method Not Allowed
    [mess setResponse:response];
    CFRelease(response);
}

@end


@implementation HTTPServerRequest

- (id)init {
    [self dealloc];
    return nil;
}

- (id)initWithRequest:(CFHTTPMessageRef)req connection:(HTTPConnection *)conn {
    connection = conn;
    request = (CFHTTPMessageRef)CFRetain(req);
    return self;
}

- (void)dealloc {
    if (request) CFRelease(request);
    if (response) CFRelease(response);
    [responseStream release];
    [super dealloc];
}

- (HTTPConnection *)connection {
    return connection;
}

- (CFHTTPMessageRef)request {
    return request;
}

- (CFHTTPMessageRef)response {
    return response;
}

- (void)setResponse:(CFHTTPMessageRef)value {
    if (value != response) {
        if (response) CFRelease(response);
        response = (CFHTTPMessageRef)CFRetain(value);
        if (response) {
            // check to see if the response can now be sent out
            [connection processOutgoingBytes];
        }
    }
}

- (NSInputStream *)responseBodyStream {
    return responseStream;
}

- (void)setResponseBodyStream:(NSInputStream *)value {
    if (value != responseStream) {
        [responseStream release];
        responseStream = [value retain];
    }
}

@end

