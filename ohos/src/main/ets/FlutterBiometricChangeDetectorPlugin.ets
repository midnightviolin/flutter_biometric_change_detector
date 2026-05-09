import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { userAuth } from '@kit.UserAuthenticationKit';
import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL_NAME = 'BIOMETRIC_CHANGE';
const PREFS_NAME = 'biometric_change_prefs';
const KEY_CREDENTIAL_DIGEST = 'credential_digest';
const KEY_CREDENTIAL_COUNT = 'credential_count';
const INVALID_VALUE = -1;

export default class FlutterBiometricChangeDetectorPlugin
  implements FlutterPlugin, MethodCallHandler {

  private channel: MethodChannel | null = null;
  private context: Context | null = null;

  getUniqueClassName(): string {
    return 'FlutterBiometricChangeDetectorPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
    this.channel = null;
    this.context = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'checkBiometricChange') {
      this.checkForBiometricChanges(result);
    } else {
      result.notImplemented();
    }
  }

  private checkForBiometricChanges(result: MethodResult): void {
    let enrolledState: userAuth.EnrolledState | null = null;

    const authTypes: userAuth.UserAuthType[] = [
      userAuth.UserAuthType.FINGERPRINT,
      userAuth.UserAuthType.FACE,
    ];
    for (const authType of authTypes) {
      try {
        enrolledState = userAuth.getEnrolledState(authType);
        break;
      } catch (e) {
        continue;
      }
    }

    if (enrolledState === null) {
      result.success('unknown');
      return;
    }

    const currentDigest: number = enrolledState.credentialDigest;
    const currentCount: number = enrolledState.credentialCount;

    preferences.getPreferences(this.context!, PREFS_NAME).then((prefs: preferences.Preferences) => {
      const storedDigest = prefs.getSync(KEY_CREDENTIAL_DIGEST, INVALID_VALUE) as number;
      const storedCount = prefs.getSync(KEY_CREDENTIAL_COUNT, INVALID_VALUE) as number;

      let status: string;

      if (storedDigest === INVALID_VALUE) {
        status = 'biometricValid';
      } else if (currentDigest !== storedDigest) {
        status = 'biometricChanged';
      } else if (currentCount < storedCount) {
        status = 'biometricChanged';
      } else {
        status = 'biometricValid';
      }

      prefs.putSync(KEY_CREDENTIAL_DIGEST, currentDigest);
      prefs.putSync(KEY_CREDENTIAL_COUNT, currentCount);
      prefs.flush();

      result.success(status);
    }).catch((err: BusinessError) => {
      result.success('unknown');
    });
  }
}
