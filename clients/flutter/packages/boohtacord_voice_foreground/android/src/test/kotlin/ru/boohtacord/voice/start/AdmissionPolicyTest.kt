package ru.boohtacord.voice.start

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdmissionPolicyTest {
    @Test fun visibleGrantedCanStart() { assertTrue(AdmissionPolicy.permitsStart(false, true, true)) }
    @Test fun backgroundCannotStartFreshService() { assertFalse(AdmissionPolicy.permitsStart(false, false, true)) }
    @Test fun permissionRequiredEvenWhileVisible() { assertFalse(AdmissionPolicy.permitsStart(false, true, false)) }
    @Test fun activeGrantedServiceCanContinueInBackground() { assertTrue(AdmissionPolicy.permitsStart(true, false, true)) }
    @Test fun revokedPermissionCannotReuseActiveService() { assertFalse(AdmissionPolicy.permitsStart(true, false, false)) }
}
