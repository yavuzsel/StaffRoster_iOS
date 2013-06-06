/*
 * JBoss, Home of Professional Open Source.
 * Copyright Red Hat, Inc., and individual contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "AGPageParameterExtractor.h"

/**
 * Abstract base class that concrete page extractor implementations can derive for.
 * Used to provide useful methods, that implementions can use.
 */
@interface AGPageBaseExtractor : NSObject<AGPageParameterExtractor>

/**
 * Parses a query string of the form "?param1=val1&param2=val&.." and
 * returns a dictionary with the params encapsulated as a key/value pairs.
 * Note: If a prefix of 'http://.." location is present, it is choped prior parsing.
 *
 * @returns an NSDictionary with the parsed key-value params.
 */
- (NSDictionary *) transformQueryString:(NSString *)value;

@end
