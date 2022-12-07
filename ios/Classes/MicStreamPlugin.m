#import "MicStreamPlugin.h"
#import <mic_stream/mic_stream-Swift.h>

@implementation MicStreamPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAudioStreamsPlugin registerWithRegistrar:registrar];
}
@end
