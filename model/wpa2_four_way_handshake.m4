// This is a Tamarin model of IEEE 802.11's WPA2 protocol

dnl Lines starting with 'dnl' are comments for the preprocessor m4.

dnl Set 'INCLUDE_PATCHES' to true/false to activate/deactivate the patches
dnl aimed at preventing key-reinstallation attacks.
define(INCLUDE_PATCHES, true)

dnl Tamarin uses '', which is an m4 close quote, so use <! !> for quoting.
changequote(<!,!>)
changecom(<!/*!>, <!*/!>)

dnl Below are definitions of m4 constants used in the rest of the file
define(kNullPTK, KDF('NULL', 'NULL', 'NULL'))
define(kNullGTK, GTK('NULL'))
define(kNullGTKNonce, <!<N('NULL'), 'NULL'>!>)
define(kNullGTKIndex, 'NULL')
define(kPTKNonceStartNumber, N('1'))
define(kRequestSleep, 'REQUEST_SLEEP')
define(kAcceptSleep, 'ACCEPT_SLEEP')
define(kRequestAwake, 'REQUEST_AWAKE')
define(kAcceptAwake, 'ACCEPT_AWAKE')

theory wpa2_four_way_handshake 

begin

// S denotes the successor function, GTK indicates that we are
// dealing with a group key
functions: KDF/1, GTK/1, N/1, snenc/3, sndec/2, S/1, MIC/2
builtins: symmetric-encryption, multiset
equations: sndec(snenc(message, key, nonce), key) = message

// BEGIN Restrictions

restriction Neq:
    "All x y #i. Neq(x, y) @ i ==> not(x = y)"

restriction Equality:
    "All x y #i. Eq(x,y) @ i ==> x = y"

restriction MessagesAreSentInEnqueueOrder:
    "All senderThreadID messageID1 messageID2 #i1 #j1 #i2 #j2.
     EnqueueMessage(senderThreadID, messageID1) @ i1 &
     EnqueueMessage(senderThreadID, messageID2) @ j1 &
     SendMessage(senderThreadID, messageID1) @ i2 &
     SendMessage(senderThreadID, messageID2) @ j2 &
     #i1 < #j1
     ==> #i2 < #j2"

// According to the standard, the supplicant only accepts messages 1 and 3 if 
// it hasn't seen their replay counters before.
restriction ReplayCounterM1:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr_m1 #i.
     SupplicantReceivesM1(suppThreadID, suppID, PMK, authThreadID, PTK, 
                          GTK, ANonce, SNonce, ctr_m1) @ i
     ==> not Ex #j. j < i & 
                    SupplicantSeesCounter(suppThreadID, PMK, ctr_m1) @ j"

restriction ReplayCounterM1Again:
	"All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr_m1 #i.
	 SupplicantReceivesM1Again(suppThreadID, suppID, PMK, authThreadID, PTK, 
                               GTK, ANonce, SNonce, ctr_m1) @ i
     ==> not Ex #j. j < i & 
                    SupplicantSeesCounter(suppThreadID, PMK, ctr_m1) @ j"

restriction ReplayCounterM3:
    "All suppThreadID suppID PMK authThreadID PTK ANonce SNonce GTK ctr_m3 #i.
     SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID, PTK, 
                          GTK, ANonce, SNonce, ctr_m3) @ i
     ==> not Ex #j. j < i & 
                    SupplicantSeesCounter(suppThreadID, PMK, ctr_m3) @ j"

restriction ReplayCounterM3Again:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr_m3 #i.
     SupplicantReceivesM3Again(suppThreadID, suppID, PMK, authThreadID, PTK, 
                               GTK, ANonce, SNonce, ctr_m3) @ i
     ==> not Ex #j. j < i & 
                    SupplicantSeesCounter(suppThreadID, PMK, ctr_m3) @ j"

restriction ReplayCounterGroupKeyRekey:
    "All suppThreadID suppID PMK authThreadID PTK oldGTK newGTK ANonce SNonce ctr #i.
     SupplicantGroupKeyRekey(suppThreadID, suppID, PMK, authThreadID, PTK, 
                             oldGTK, newGTK, ANonce, SNonce, ctr) @ i
     ==> not Ex #j. j < i & 
                    SupplicantSeesCounter(suppThreadID, PMK, ctr) @ j"

restriction ReplayCounterPairwiseMessages:
    "All ptkID receiverThreadID senderID PTK n1 n2 #i #j.
     SeesNonceForPTK(ptkID, receiverThreadID, PTK, <N(n1), senderID>) @ i &
     SeesNonceForPTK(ptkID, receiverThreadID, PTK, <N(n2), senderID>) @ j & 
     i < j
     ==>  Ex z. n1 + z = n2"

restriction ReplayCounterGroupPayload:
    "All keyID receiverThreadID senderID groupKey n1 n2 #i #j.
     SeesNonceForGTK(keyID, receiverThreadID, groupKey, <N(n1), senderID>) @ i &
     SeesNonceForGTK(keyID, receiverThreadID, groupKey, <N(n2), senderID>) @ j & 
     i < j
     ==>  Ex z. n1 + z = n2"

restriction MemoryCanBeFreedOnlyOnce:
    "All pointer #i #j. Free(pointer) @ i & Free(pointer) @ j ==> #i = #j"

restriction FreedMemoryCannotBeAccessed:
    "All pointer #i #j. Read(pointer) @ i & Free(pointer) @ j ==> i < j" 

restriction FreedUniqueMemoryCannotBeAccessed:
    "All pointer owner #i #j. ReadUnique(pointer, owner) @ i & 
     Free(pointer) @ j ==> i < j" 

restriction UniqueMemoryMustBeUnique:
    "All pointer1 owner #i #j. 
     AllocateUnique(pointer1, owner) @ i &
     ReadUnique(pointer1, owner) @ j
     ==> i < j & 
         not(Ex pointer2 #k. i < k & k < j & 
             AllocateUnique(pointer2, owner) @ k)"

// END Restrictions

// BEGIN Setup

rule Supp_Create [color=b5d1ff]:
    [ Fr(~suppID) ] 
    --[ SupplicantCreated(~suppID) ]-> 
    [ !Supplicant(~suppID)
    , Out(~suppID) ] // We view the ID as the MAC address, so publish it

rule Auth_Create [color=ddb4ff]:
    let
        gtk4 = GTK(~x)
        gtkNonce = <N('1'), ~authID>
        gtk4Data = <gtk4, gtkNonce, '4'>
        installedGTKData = gtk4Data
        shareGTKData = gtk4Data
    in
    [ Fr(~authID) 
    , Fr(~pointerGTKState)
    , Fr(~x) ] 
    --[ AuthenticatorCreated(~authID)
      , AuthenticatorInstalledGTK(~authID, installedGTKData)
      , AuthenticatorSetsShareGTK(~authID, shareGTKData)
      , AllocateUnique(~pointerGTKState, ~authID) ]-> 
    [ !Authenticator(~authID) 
    , !AuthGTKState(~authID, 'SETKEYSDONE', installedGTKData, shareGTKData,
                    ~pointerGTKState) 
    , AuthInstalledGTK(~authID, installedGTKData) 
    , Out(~authID) ]

rule Auth_Associate_With_Supp:
    let
        ctr_start = S('0')
        initialPTK = kNullPTK
        initialSuppGTKData = <kNullGTK, kNullGTKNonce, kNullGTKIndex>
    in
    [ Fr(~PMK)
    , Fr(~authThreadID)
    , Fr(~suppThreadID)
    , Fr(~authPTKID)
    , Fr(~suppPTKID)
    , Fr(~pointerAuthPTK)
    , Fr(~pointerSuppPTK)
    , Fr(~nullGTKID)
    , !Authenticator(~authID)
    , !Supplicant(~suppID) ]
    --[ Init(~PMK)
      , Associate(~authID, ~authThreadID, ~suppID, ~suppThreadID, ~PMK) ]->
    [ AuthState(~authThreadID, 'INIT_R1_SA', <~authID, ~PMK, ~suppThreadID, initialPTK, 
                'NULL_ANonce', 'NULL_SNonce', ctr_start>)
    , SuppState(~suppThreadID, 'INIT_R1_SA', 
                <~suppID, ~PMK, ~authThreadID, initialPTK, initialSuppGTKData, 
                 'NULL_ANonce', 'NULL_SNonce', S('NULL')>)
    , !PairwiseMasterKey(~PMK, ~authID, ~authThreadID, ~suppID, ~suppThreadID)
    , !AuthReceiverPTK(~authPTKID, ~authThreadID, ~authID, initialPTK,
                       ~pointerAuthPTK)
    , !SuppReceiverPTK(~suppPTKID, ~suppThreadID, ~suppID, initialPTK, 
                       ~pointerSuppPTK)
    , ReceiverGTK(~suppThreadID, ~nullGTKID, ~PMK,
                  kNullGTK, kNullGTKNonce, kNullGTKIndex)
    , Out(~authThreadID)
    , Out(~suppThreadID) ]

// END Setup

// BEGIN Encryption Layer

include(encryption_layer.m4i)

rule receiveGTKEncryptedPayload [color=fcac86]:
    let 
        GTK = GTK(x)
        lastNonce = <N(n), senderID>
        incomingNonce = <N(m), senderID> 
	in
    [ In(snenc(<'data', $message>, GTK, incomingNonce))
    , ReceiverGTK(~receiverThreadID, ~keyID, ~PMK,
                  GTK, lastNonce, $index)[no_precomp] ]
    --[ ReceiveGTKEncryptedPayload(~keyID, ~receiverThreadID, ~PMK,
                                    GTK, incomingNonce)
      , SeesNonceForGTK(~keyID, ~receiverThreadID,
                        GTK, incomingNonce)
      , Neq($index, kNullGTKIndex) ]->
    [ ReceiverGTK(~receiverThreadID, ~keyID, ~PMK, 
                  GTK, incomingNonce, $index) ]

// We have two rules for sending GTK encrypted payloads to distinguish between
// the case where the installed GTK is also the share GTK and the case 
// where the two GTKs are different.
rule sendGTKEncryptedPayload_1 [color=fcac86]:
    let 
        installedGTK = GTK(~x)
		installedGTKNonce = <N(n), ~authID>
		newGTKNonce = <N(n+'1'), ~authID>
        installedGTKData = <installedGTK, installedGTKNonce, $index>
        shareGTKData = installedGTKData
        newGTKData = <installedGTK, newGTKNonce, $index>
        newShareGTKData = newGTKData
	in
    [ AuthInstalledGTK(~authID, installedGTKData) 
    , !AuthGTKState(~authID, stateIdentifier, installedGTKData, shareGTKData,
                    ~oldPointerGTKState)[no_precomp]
    , Fr(~newPointerGTKState) ]
    --[ EncryptedWithGTK(~authID, newGTKData, newShareGTKData)
      , AuthenticatorUsesGTK(~authID, newGTKData, shareGTKData)
      , SendGTKEncryptedPayload(~authID, newGTKData, newShareGTKData)
      , AllocateUnique(~newPointerGTKState, ~authID)
      , Free(~oldPointerGTKState) ]->
    [ Out(snenc(<'data', $message>, installedGTK, newGTKNonce))
    , AuthInstalledGTK(~authID, newGTKData) 
    , !AuthGTKState(~authID, stateIdentifier, newGTKData, newGTKData, 
                    ~newPointerGTKState) ]

rule sendGTKEncryptedPayload_2 [color=fcac86]:
    let 
        installedGTK = GTK(~x)
		installedGTKNonce = <N(n), ~authID>
		newGTKNonce = <N(n+'1'), ~authID>
        installedGTKData = <installedGTK, installedGTKNonce, $index>
        shareGTKData = <shareGTK, shareGTKNonce, $shareIndex>
        newGTKData = <installedGTK, newGTKNonce, $index>
	in
    [ AuthInstalledGTK(~authID, installedGTKData)
    , !AuthGTKState(~authID, stateIdentifier, installedGTKData, shareGTKData,
                    ~oldPointerGTKState)[no_precomp]
    , Fr(~newPointerGTKState) ]
    --[ EncryptedWithGTK(~authID, newGTKData, shareGTKData)
      , AuthenticatorUsesGTK(~authID, newGTKData, shareGTKData)
      , SendGTKEncryptedPayload(~authID, newGTKData, shareGTKData)
      , AllocateUnique(~newPointerGTKState, ~authID)
      , AllocateUnique(~newPointerGTKState, ~authID)
      , Free(~oldPointerGTKState)
      , Neq(installedGTK, shareGTK) ]->
    [ Out(snenc(<'data', $message>, installedGTK, newGTKNonce))
    , AuthInstalledGTK(~authID, newGTKData)
    , !AuthGTKState(~authID, stateIdentifier, newGTKData, shareGTKData,
                    ~newPointerGTKState) ]

rule KeyRevealFromNonceReuse [color=aa0000]:
    let encrypted_m1 = snenc(m1, key, nonce)
        encrypted_m2 = snenc(m2, key, nonce)
    in
    [ In(<encrypted_m1, encrypted_m2>)[+] ]
    --[ Neq(m1, m2), NonceReuse(key, nonce) ]->
    [ Out(key) ]

// END Encryption Layer

// BEGIN Reveal Pairwise Master Key

rule KeyRevealPMK [color=ffffff]:
    [ !PairwiseMasterKey(~PMK, ~authID, ~authThreadID, ~suppID, ~suppThreadID) ]
    --[ RevealPMK(~PMK)
      , RevealPMKFor(~PMK, ~authID, ~authThreadID, ~suppID, ~suppThreadID) ]->
    [ Out(~PMK) ]

// END Reveal Pairwise Master Key

// BEGIN PTK state machine for the authenticator (R1KH)

rule Auth_Snd_M1 [color=ddb4ff]:
    let 
        ctr = S(ctr_minus_1)
        ctr_plus_1 = S(ctr)
        m1 = <ctr_plus_1, ~ANonce>
        PTK = KDF(<PMK1, ANonce1, SNonce1>) 
    in
    [ AuthState(~authThreadID, 'INIT_R1_SA', 
                <~authID, ~PMK, ~suppThreadID, PTK, oldANonce, oldSNonce, ctr>)
    , Fr(~ANonce) 
    , Fr(~messageID) ]
    --[ AuthenticatorSendsM1(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                             ~ANonce, oldSNonce, ctr_plus_1) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
    [ AuthState(~authThreadID, 'PTK_START', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, oldSNonce, ctr_plus_1>)
    , !UsedCounterInPTKHandshake(~authThreadID, ~ANonce, ctr_plus_1)
    , OutEnc(m1, ~authThreadID, ~messageID, Auth_Snd_M1, Auth) ]

OutEncRule(Auth_Snd_M1, Auth)

rule Auth_Snd_M1_repeat [color=ddb4ff]:
    let 
        PTK = KDF(<PMK1, ANonce1, SNonce1>) 
        ctr = S(ctr_minus_1)
        ctr_plus_1 = S(ctr)
        m1 = <ctr_plus_1, ~ANonce>
    in
    [ AuthState(~authThreadID, 'PTK_START', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, oldSNonce, ctr>) 
    , Fr(~messageID) ]
    --[ AuthenticatorSendsM1Again(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                                  ~ANonce, oldSNonce, ctr_plus_1) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
    [ AuthState(~authThreadID, 'PTK_START', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, oldSNonce, ctr_plus_1>)
    , !UsedCounterInPTKHandshake(~authThreadID, ~ANonce, ctr_plus_1)
    , OutEnc(m1, ~authThreadID, ~messageID, Auth_Snd_M1_repeat, Auth) ]

OutEncRule(Auth_Snd_M1_repeat, Auth)

rule Auth_Rcv_M2 [color=ddb4ff]:
    let 
        ctr = S(ctr_minus_1)
        m2 = <ctr, SNonce>
        PTK = KDF(<PMK1, ANonce1, SNonce1>) 
    in
    [ AuthState(~authThreadID, 'PTK_START', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, oldSNonce, ctr>)
	, InEnc(<!<m2, mic_m2>!>, ~authThreadID, PTK, Auth)[no_precomp] ]
    --[ AuthenticatorReceivesM2(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                                ~ANonce, SNonce, ctr) ]->
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr, <m2, mic_m2>>) ]

rule Auth_Rcv_M2_repeat [color=ddb4ff]:
    let 
        PTK = KDF(<PMK1, ANonce1, SNonce1>) 
        ctr = S(ctr_minus_1)
        previous_ctr = S(previous_ctr_minus_1)
        previous_m2 = <previous_ctr, SNonce>
        m2 = <ctr, SNonce>
    in
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING', <~authID, ~PMK, ~suppThreadID, PTK,
                ~ANonce, oldSNonce, ctr, <previous_m2, previous_mic_m2>>)
	, InEnc(<!<m2, mic_m2>!>, ~authThreadID, PTK, Auth)[no_precomp] ]
    --[ AuthenticatorReceivesM2Again(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                                     ~ANonce, SNonce, ctr) ]->
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING',
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr, <m2, mic_m2>>) ]

rule Auth_Check_MIC_M2_Snd_M3 [color=ddb4ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ~ANonce, SNonce>)
        groupKey = GTK(~x)
        groupNonce = <N(n), ~authID>
        shareGTKData = <groupKey, groupNonce, $index>
        ctr = S(ctr_minus_1)
        ctr_plus_1 = S(ctr)
        m2 = <ctr, SNonce>
        m3 = <ctr_plus_1, senc(<groupKey, groupNonce, $index>, newPTK)>
    in
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING',
                <~authID, ~PMK, ~suppThreadID, oldPTK, ~ANonce, SNonce, ctr, <m2, mic_m2>>)
    , !AuthGTKState(~authID, stateIdentifier, installedGTKData, shareGTKData,
                    ~pointerGTKState)[no_precomp] 
    , Fr(~messageID) ]
    --[ Eq(mic_m2, MIC(newPTK, m2))
      , AuthenticatorSendsInitialM3(~authThreadID, ~authID, ~PMK, ~suppThreadID, oldPTK, 
                                    ~ANonce, SNonce, ctr_plus_1)
      , AuthenticatorRunning(~authThreadID, ~suppThreadID, 
                             ~PMK, ~ANonce, SNonce, newPTK)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSharesGTK(~authThreadID, ~authID, ~PMK, shareGTKData)
      , ReadUnique(~pointerGTKState, ~authID) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING3',
                <~authID, ~PMK, ~suppThreadID, oldPTK, ~ANonce, SNonce, ctr_plus_1>)
    , !UsedCounterInPTKHandshake(~authThreadID, ~ANonce, ctr_plus_1) 
    , OutEnc(<!<m3, MIC(newPTK, m3)>!>, ~authThreadID, ~messageID, 
             Auth_Check_MIC_M2_Snd_M3, Auth) ]

OutEncRule(Auth_Check_MIC_M2_Snd_M3, Auth)

rule Auth_Snd_M3_repeat [color=ddb4ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ~ANonce, SNonce>)
        groupKey = GTK(~x)
        groupNonce = <N(n), ~authID>
        shareGTKData = <groupKey, groupNonce, $index>
        ctr = S(ctr_minus_1)
        ctr_plus_1 = S(ctr)
        m3 = <ctr_plus_1, senc(<groupKey, groupNonce, $index>, newPTK)>
    in
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING3', 
                <~authID, ~PMK, ~suppThreadID, oldPTK, ~ANonce, SNonce, ctr>)
    , !AuthGTKState(~authID, stateIdentifier, installedGTKData, shareGTKData,
                    ~pointerGTKState)[no_precomp] 
    , Fr(~messageID) ]
    --[ AuthenticatorSendsM3Again(~authThreadID, ~authID, ~PMK, ~suppThreadID, oldPTK, 
                                  ~ANonce, SNonce, ctr_plus_1)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSharesGTK(~authThreadID, ~authID, ~PMK, shareGTKData)
      , ReadUnique(~pointerGTKState, ~authID) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING3', 
                <~authID, ~PMK, ~suppThreadID, oldPTK, ~ANonce, SNonce, ctr_plus_1>)
    , !UsedCounterInPTKHandshake(~authThreadID, ~ANonce, ctr_plus_1)
    , OutEnc(<!<m3, MIC(newPTK, m3)>!>, ~authThreadID, ~messageID, 
             Auth_Snd_M3_repeat, Auth) ]

OutEncRule(Auth_Snd_M3_repeat, Auth)

// Might want to check if we accept messages encrypted with the old PTK
rule Auth_Rcv_M4_Install_Key [color=ddb4ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ~ANonce, SNonce>)
        ptkNonce = <kPTKNonceStartNumber, ~authID>
        ctr = S(ctr_minus_1)
        fresh_ctr = S(~counter)
        m4 = S(ctr_m4_minus_1)
    in
    [ AuthState(~authThreadID, 'PTK_CALC_NEGOTIATING3', 
                <~authID, ~PMK, ~suppThreadID, oldPTK, ~ANonce, SNonce, ctr>)
    , !AuthReceiverPTK(~oldPTKID, ~authThreadID, ~authID, oldPTK,
                       ~oldPointerPTK)[no_precomp] 
    , InEnc(<!<m4, mic_m4>!>, ~authThreadID, oldPTK, Auth)[no_precomp, -]
    , !UsedCounterInPTKHandshake(~authThreadID, ~ANonce, m4)[-]
    , Fr(~ptkID)
	, Fr(~gtkID)
    , Fr(~counter)
    , Fr(~newPointerPTK) ]
    --[ AuthenticatorInstalled(~authThreadID, ~authID, ~PMK, ~suppThreadID, newPTK, 
                               ~ANonce, SNonce, ctr)
      , AuthenticatorCommit(~authThreadID, ~suppThreadID, 
                            ~PMK, ~ANonce, SNonce, newPTK)
      , InstalledPTK(~ptkID, ~authThreadID, ~authID, newPTK, ptkNonce)
      , AuthInstalledPTK(~ptkID, ~authThreadID, ~authID, newPTK, ptkNonce)
      , EncryptedWithOrInstalledPTK(~ptkID, ~authThreadID, ~authID,
                                    newPTK, ptkNonce)
      , Eq(mic_m4, MIC(newPTK, m4))
      , Free(~oldPointerPTK) ]->
    [ AuthState(~authThreadID, 'PTK_INIT_DONE', 
                <~authID, ~PMK, ~suppThreadID, newPTK, ~ANonce, SNonce, fresh_ctr>)
    , AuthStartWNMSleepModeThread(~authThreadID, ~authID, ~PMK, oldPTK)
    , AuthSenderPTK(~ptkID, ~authThreadID, ~authID, newPTK, ptkNonce)
    , !AuthReceiverPTK(~ptkID, ~authThreadID, ~authID, newPTK,
                       ~newPointerPTK) ]

rule Auth_Rekey_PTK [color=a333ff]:
     let
        PTK = KDF(<~PMK, ~ANonce, SNonce>)
        ctr = S(ctr_minus_1)
     in
     [ AuthState(~authThreadID, 'PTK_INIT_DONE', 
                 <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr>) ]
     --[ AuthenticatorRekeyPTK(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                               ~ANonce, SNonce, ctr) ]->
     [ AuthState(~authThreadID, 'INIT_R1_SA', 
                 <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr>) ]

// END PTK state machine for the authenticator (R1KH)

// BEGIN PTK state machine for the supplicant (S1KH)

rule Supp_Rcv_M1_Snd_M2 [color=b5d1ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ANonce, ~SNonce>)
		GTK = GTK(x)
        GTKNonce = <N(n), authID>
        GTKData = <GTK, GTKNonce, $index>
        ctr = S(ctr_m1_minus_1)
        oldCtr = S(oldCtr_minus_1)
        m1 = <ctr, ANonce>
        m2 = <ctr, ~SNonce>
    in
    [ SuppState(~suppThreadID, 'INIT_R1_SA', <~suppID, ~PMK, ~authThreadID, oldPTK, GTKData, 
                oldANonce, oldSNonce, oldCtr>)
    , InEnc(m1, ~suppThreadID, oldPTK, Supp)[no_precomp] 
    , Fr(~SNonce)
    , Fr(~messageID) ]
    --[ SupplicantReceivesM1(~suppThreadID, ~suppID, ~PMK, ~authThreadID, oldPTK, GTK,
                             ANonce, ~SNonce, ctr),
        SupplicantSeesCounter(~suppThreadID, ~PMK, ctr) 
      , EnqueueMessage(~suppThreadID, ~messageID) ]->
    [ SuppState(~suppThreadID, 'PTK_START', <~suppID, ~PMK, ~authThreadID, oldPTK, GTKData, 
                ANonce, ~SNonce, ctr>) 
    , OutEnc(<!<m2, MIC(newPTK, m2)>!>, ~suppThreadID, ~messageID, 
             Supp_Rcv_M1_Snd_M2, Supp) ]

OutEncRule(Supp_Rcv_M1_Snd_M2, Supp)

// Here we assume that the Supplicant only accepts resends of message 1 if they 
// contain the same ANonce as the original message 1. The standard does not 
// explicitly state this, but it seems like a reasonable interpretation.
rule Supp_Rcv_M1_Snd_M2_repeat [color=b5d1ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ANonce, ~SNonce>)
		GTK = GTK(x)
        GTKNonce = <N(n), authID>
        GTKData = <GTK, GTKNonce, $index>
        ctr_prev = S(ctr_minus_1_prev)
        ctr = S(ctr_rercv_m1_minus_1)
        m1 = <ctr, ANonce>
        m2 = <ctr, ~SNonce>
    in
    [ SuppState(~suppThreadID, 'PTK_START', <~suppID, ~PMK, ~authThreadID, oldPTK, GTKData, 
                ANonce, ~SNonce, ctr_prev>)
    , InEnc(m1, ~suppThreadID, oldPTK, Supp)[no_precomp] 
    , Fr(~messageID) ] 
    --[ SupplicantReceivesM1Again(~suppThreadID, ~suppID, ~PMK, ~authThreadID, oldPTK,
                                  GTK, ANonce, ~SNonce, ctr)
      , SupplicantSeesCounter(~suppThreadID, ~PMK, ctr) 
      , EnqueueMessage(~suppThreadID, ~messageID) ]->
    [ SuppState(~suppThreadID, 'PTK_START', <~suppID, ~PMK, ~authThreadID, oldPTK, GTKData,
                ANonce, ~SNonce, ctr>)
    , OutEnc(<!<m2, MIC(newPTK, m2)>!>, ~suppThreadID, ~messageID, 
             Supp_Rcv_M1_Snd_M2_repeat, Supp) ]

OutEncRule(Supp_Rcv_M1_Snd_M2_repeat, Supp)


rule Supp_Rcv_M3 [color=b5d1ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ANonce, ~SNonce>)
        ctr = S(ctr_minus_1)
        ctr_m3 = S(ctr_m3_minus_1)
        newGTK = GTK(x)
        newGTKNonce = <N(n), authID1>
        newGTKData = <newGTK, newGTKNonce, $newIndex>
        oldGTK = GTK(y)
        oldGTKNonce = <N(m), authID2>
        oldGTKData = <oldGTK, oldGTKNonce, $oldIndex>
        m3 = <ctr_m3, senc(newGTKData, newPTK)>
    in
    [ SuppState(~suppThreadID, 'PTK_START', <~suppID, ~PMK, ~authThreadID, oldPTK,
                oldGTKData, ANonce, ~SNonce, ctr>) 
    , InEnc(<!<m3, mic_m3>!>, ~suppThreadID, oldPTK, Supp)[no_precomp] ]
    --[ SupplicantReceivesM3(~suppThreadID, ~suppID, ~PMK, ~authThreadID, oldPTK, newGTK, 
                             ANonce, ~SNonce, ctr_m3)
      , SupplicantSeesCounter(~suppThreadID, ~PMK, ctr_m3)
      , Eq(mic_m3, MIC(newPTK, m3)) ]->
    [ SuppState(~suppThreadID, 'PTK_CALC_NEGOTIATING', 
                <~suppID, ~PMK, ~authThreadID, oldPTK, oldGTKData, newGTKData, 
                 ANonce, ~SNonce, ctr_m3>) ]

rule Supp_Install_Key_Snd_M4 [color=b5d1ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ANonce, ~SNonce>)
        ctr_m3 = S(ctr_m3_minus_1)
        newGTK = GTK(x)
        newGTKNonce = <N(n), authID1>
        newGTKData = <newGTK, newGTKNonce, $newIndex>
        oldGTK = GTK(y)
        oldGTKNonce = <N(m), authID2>
        oldGTKData = <oldGTK, oldGTKNonce, $oldIndex>
        m4 = ctr_m3
    in
    [ SuppState(~suppThreadID, 'PTK_CALC_NEGOTIATING', 
                <~suppID, ~PMK, ~authThreadID, oldPTK, oldGTKData, newGTKData,
                 ANonce, ~SNonce, ctr_m3>)
    , ReceiverGTK(~suppThreadID, ~oldGTKID, ~PMK,
                  oldGTK, oldGTKNonce, $oldIndex)
	, Fr(~newGTKID) 
    , Fr(~messageID) ]
    --[ SupplicantSendsM4(~suppThreadID, ~suppID, ~PMK, ~authThreadID, newPTK, newGTK, 
                          ANonce, ~SNonce) 
      , SupplicantInstalledGTK(~newGTKID, ~suppThreadID, ~PMK,
                               newGTK, newGTKNonce, $newIndex)
      , SupplicantRunning(~suppThreadID, ~authThreadID, 
                          ~PMK, ANonce, ~SNonce, newPTK)
      , SupplicantCommit(~suppThreadID, ~authThreadID, 
                          ~PMK, ANonce, ~SNonce, newPTK)
      , SeesNonceForGTK(~newGTKID, ~suppThreadID, newGTK, newGTKNonce)
      , EnqueueMessage(~suppThreadID, ~messageID)
      ifelse(INCLUDE_PATCHES, true, <!, Neq(oldGTK, newGTK)!>,) ]->
    [ SuppState(~suppThreadID, 'PTK_INIT_DONE',
                <~suppID, ~PMK, ~authThreadID, newPTK, newGTKData, 
                 ANonce, ~SNonce, ctr_m3>)
    , OutEnc(<!<m4, MIC(newPTK, m4)>!>, ~suppThreadID, ~messageID,
             Supp_Install_Key_Snd_M4, Supp) 
    , SuppInstallPTKCommand(~suppThreadID, ~suppID, ~PMK, newPTK, oldPTK, 
                 newGTK, ANonce, ~SNonce) 
    , ReceiverGTK(~suppThreadID, ~newGTKID, ~PMK, 
                  newGTK, newGTKNonce, $newIndex) ]

OutEncRule(Supp_Install_Key_Snd_M4, Supp)

rule Supp_Install_PTK [color=ffc300]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ANonce, ~SNonce>)
        ptkNonce = <kPTKNonceStartNumber, ~suppID>
        GTK = GTK(x)
    in
    [ Fr(~ptkID)
    , Fr(~pointerNewRcvPTK)
    , SuppInstallPTKCommand(~suppThreadID, ~suppID, ~PMK, newPTK, oldPTK, 
                 GTK, ANonce, ~SNonce)
    , !SuppReceiverPTK(~oldPtkID, ~suppThreadID, ~suppID, oldPTK, 
                       ~pointerOldRcvPTK)[no_precomp] ]
    --[ SupplicantInstalledPTK(~suppThreadID, ~suppID, ~PMK, ~ptkID, newPTK, 
                               ptkNonce, GTK, ANonce, ~SNonce)
      , InstalledPTK(~ptkID, ~suppThreadID, ~suppID, newPTK, ptkNonce) 
      , EncryptedWithOrInstalledPTK(~ptkID, ~suppThreadID, ~suppID,
                                    newPTK, ptkNonce) 
      , Free(~pointerOldRcvPTK)
      ifelse(INCLUDE_PATCHES, true, <!, Neq(oldPTK, newPTK)!>,)
      ]->
    [ SuppSenderPTK(~ptkID, ~suppThreadID, ~suppID, newPTK, ptkNonce)
    , !SuppReceiverPTK(~ptkID, ~suppThreadID, ~suppID, newPTK, 
                       ~pointerNewRcvPTK)
    , SuppStartWNMSleepModeThread(~suppThreadID, ~suppID, ~PMK, oldPTK) ]

rule Supp_Rcv_M3_repeat [color=b5d1ff]:
    let 
        oldPTK = KDF(<PMK1, ANonce1, SNonce1>)
        newPTK = KDF(<~PMK, ANonce, ~SNonce>)
        ctr = S(ctr_minus_1)
        ctr_m3 = S(ctr_m3_minus_1)
        newGTK = GTK(x)
        newGTKNonce = <N(n), authID1>
        newGTKData = <newGTK, newGTKNonce, $newIndex>
        oldGTK = GTK(y)
        oldGTKNonce = <N(m), authID2>
        oldGTKData = <oldGTK, oldGTKNonce, $oldIndex>
        m3 = <ctr_m3, senc(newGTKData, newPTK)>
    in
    [ SuppState(~suppThreadID, 'PTK_INIT_DONE',
                <~suppID, ~PMK, ~authThreadID, oldPTK, oldGTKData, 
                 ANonce, ~SNonce, ctr>)
    , InEnc(<!<m3, mic_m3>!>, ~suppThreadID, oldPTK, Supp)[no_precomp] ]
    --[ SupplicantReceivesM3Again(~suppThreadID, ~suppID, ~PMK, ~authThreadID, oldPTK,
                                  newGTK, ANonce, ~SNonce, ctr_m3) 
	  ,	SuppRcvM3AgainOrGroupRekey(~suppThreadID, ~suppID, ~PMK, ~authThreadID, oldPTK, 
                                   newGTK, ANonce, ~SNonce, ctr_m3)
      , SupplicantSeesCounter(~suppThreadID, ~PMK, ctr_m3)
      , Eq(mic_m3, MIC(newPTK, m3)) ]->
    [ SuppState(~suppThreadID, 'PTK_CALC_NEGOTIATING', 
                <~suppID, ~PMK, ~authThreadID, oldPTK, oldGTKData, newGTKData, 
                 ANonce, ~SNonce, ctr_m3>) ]


rule Supp_Rekey_PTK [color=3381ff]:
    let
        PTK = KDF(<PMK1, ANonce1, SNonce1>) 
        ctr = S(ctr_minus_1)
        GTK = GTK(x)
        GTKNonce = <N(n), authID>
        GTKData = <GTK, GTKNonce, $index>
    in
    [ SuppState(~suppThreadID, 'PTK_INIT_DONE',
                <~suppID, ~PMK, ~authThreadID, PTK, GTKData,
                 ANonce, ~SNonce, ctr>) ]
    --[ SupplicantRekeyPTK(~suppThreadID, ~suppID, ~PMK, PTK, GTK,
                        ANonce, ~SNonce, ctr) ]->
    [ SuppState(~suppThreadID, 'INIT_R1_SA', 
                <~suppID, ~PMK, ~authThreadID, PTK, GTKData,
                 ANonce, ~SNonce, ctr>) ]

// END PTK state machine for the supplicant (S1KH)

// BEGIN GTK state machines

rule Supp_Rekey_GroupKey [color=3381ff]:
	let
		PTK = KDF(<PMK1, ANonce1, SNonce1>)
        ctr = S(ctr_minus_1)
        ctr_rekey = S(ctr_rekey_minus_1)
        newGTK = GTK(x)
        newGTKNonce = <N(n), authID1>
        newGTKData = <newGTK, newGTKNonce, $newIndex>
        oldGTK = GTK(y)
        oldGTKNonce = <N(m), authID2>
        oldGTKData = <oldGTK, oldGTKNonce, $oldIndex>
		rekeyMsg = <ctr_rekey, senc(newGTKData, PTK)>	
	in
	[ SuppState(~suppThreadID, 'PTK_INIT_DONE',
                <~suppID, ~PMK, ~authThreadID, PTK, oldGTKData,
                 ANonce, ~SNonce, ctr>)
	, InEnc(<!<rekeyMsg, mic>!>, ~suppThreadID, PTK, Supp)[no_precomp]
    , ReceiverGTK(~suppThreadID, ~oldGTKID, ~PMK,
                  oldGTK, oldGTKNonce, $oldIndex)
    , Fr(~newGTKID)
    , Fr(~messageID) ]
	--[ Eq(mic, MIC(PTK, rekeyMsg))
      , SupplicantGroupKeyRekey(~suppThreadID, ~suppID, ~PMK, ~authThreadID, PTK,
                                oldGTK, newGTK, ANonce, ~SNonce, ctr_rekey)
	  ,	SuppRcvM3AgainOrGroupRekey(~suppThreadID, ~suppID, ~PMK, ~authThreadID, PTK,
                                   newGTK, ANonce, ~SNonce,  ctr_rekey)
	  , SupplicantSeesCounter(~suppThreadID, ~PMK, ctr_rekey) 
      , SupplicantInstalledGTK(~newGTKID, ~suppThreadID, ~PMK,
                               newGTK, newGTKNonce, $newIndex)
      , SeesNonceForGTK(~newGTKID, ~suppThreadID, newGTK, newGTKNonce)
      , EnqueueMessage(~suppThreadID, ~messageID)
      ifelse(INCLUDE_PATCHES, true, <!, Neq(oldGTK, newGTK)!>,) ]->
	[ SuppState(~suppThreadID, 'PTK_INIT_DONE',
                <~suppID, ~PMK, ~authThreadID, PTK, newGTKData, 
                 ANonce, ~SNonce, ctr_rekey>)
    , ReceiverGTK(~suppThreadID, ~newGTKID, ~PMK, 
                  newGTK, newGTKNonce, $newIndex)
	, OutEnc(<!<ctr_rekey, MIC(PTK, ctr_rekey)>!>, ~suppThreadID, ~messageID,
             Supp_Rekey_GroupKey, Supp) ]

OutEncRule(Supp_Rekey_GroupKey, Supp)


// We allow group key handshakes only when the authenticator is in the DONE
// state. This is in line with the standard, which says (on page 2040), 
// "An Authenticator shall do a 4-way handshake before a group key handshake 
// if both are required to be done. NOTE—The Authenticator cannot initiate the 
// group key handshake until the 4-way handshake completes successfully."

rule Auth_Start_GroupKey_Rekey_4 [color=7e2eff]:
    let
        installedGTKData = <installedGTK, installedGTKNonce, '5'>
		newGTK = GTK(~x)
        newGTKNonce = <N('1'), ~authID>
        newGTKData = <newGTK, newGTKNonce, '4'>
    in
    [ !AuthGTKState(~authID, state_identifier, installedGTKData, shareGTKData,
                    ~oldPointerGTKState)[no_precomp]
    , Fr(~newPointerGTKState)
    , Fr(~x) ]
    --[ AuthenticatorStartsGTKRekey(~authID, installedGTKData, 
                                    shareGTKData, newGTKData)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSetsShareGTK(~authID, newGTKData)
      , AllocateUnique(~newPointerGTKState, ~authID)
      , Free(~oldPointerGTKState) ]->
    [ !AuthGTKState(~authID, 'SETKEYS', installedGTKData, newGTKData, 
                    ~newPointerGTKState)
    , AuthInstallGTKCommand(~authID, newGTKData) ]

rule Auth_Start_GroupKey_Rekey_5 [color=7e2eff]:
    let
        installedGTKData = <installedGTK, installedGTKNonce, '4'>
		newGTK = GTK(~x)
        newGTKNonce = <N('1'), ~authID>
        newGTKData = <newGTK, newGTKNonce, '5'>
    in
    [ !AuthGTKState(~authID, state_identifier, installedGTKData, shareGTKData, 
                    ~oldPointerGTKState)[no_precomp]
    , Fr(~newPointerGTKState)
    , Fr(~x) ]
    --[ AuthenticatorStartsGTKRekey(~authID, installedGTKData, 
                                    shareGTKData, newGTKData)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSetsShareGTK(~authID, newGTKData)
      , AllocateUnique(~newPointerGTKState, ~authID)
      , Free(~oldPointerGTKState) ]->
    [ !AuthGTKState(~authID, 'SETKEYS', installedGTKData, newGTKData, 
                    ~newPointerGTKState)
    , AuthInstallGTKCommand(~authID, newGTKData) ]


rule Auth_Rekey_GroupKey_Init [color=a333ff]:
	let
		PTK = KDF(<PMK1, ANonce1, SNonce1>)
		shareGTK = GTK(~x)
        shareGTKNonce = <N('1'), ~authID>
        shareGTKData = <shareGTK, shareGTKNonce, $shareGTKIndex>
        ctr = S(ctr_minus_1)
		ctr_plus_1 = S(ctr)
		rekeyMsg = <ctr_plus_1, senc(shareGTKData, PTK)>
	in
	[ AuthState(~authThreadID, 'PTK_INIT_DONE', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr>)
    , !AuthGTKState(~authID, 'SETKEYS', installedGTKData, shareGTKData, 
                    ~pointerGTKState)[no_precomp] 
    , Fr(~messageID) ]
	--[ AuthenticatorInitsGroupKeyRekey(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                                ~ANonce, SNonce, ctr_plus_1, shareGTKData)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSharesGTK(~authThreadID, ~authID, ~PMK, shareGTKData)
      , ReadUnique(~pointerGTKState, ~authID) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
	[ AuthState(~authThreadID, 'REKEYNEGOTIATING', <~authID, ~PMK, ~suppThreadID, PTK, 
                ~ANonce, SNonce, ctr_plus_1, shareGTKData>)
    , !UsedCounterInGTKHandshake(~authThreadID, shareGTKData, ctr_plus_1) 
	, OutEnc(<!<rekeyMsg, MIC(PTK, rekeyMsg)>!>, ~authThreadID, ~messageID,
             Auth_Rekey_GroupKey_Init, Auth) ]

OutEncRule(Auth_Rekey_GroupKey_Init, Auth)

rule Auth_Rekey_GroupKey_Init_repeat [color=a333ff]:
	let
		PTK = KDF(<PMK1, ANonce1, SNonce1>)
		shareGTK = GTK(~x)
        shareGTKNonce = <N('1'), ~authID>
        shareGTKData = <shareGTK, shareGTKNonce, $shareGTKIndex>
        ctr = S(ctr_minus_1)
		ctr_plus_1 = S(ctr)
		rekeyMsg = <ctr_plus_1, senc(shareGTKData, PTK)>
	in
	[ AuthState(~authThreadID, 'REKEYNEGOTIATING', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr, shareGTKData>)
    , !AuthGTKState(~authID, 'SETKEYS', installedGTKData, shareGTKData,
                    ~pointerGTKState)[no_precomp] 
    , Fr(~messageID) ]
	--[ AuthenticatorInitsGroupKeyRekeyAgain(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                             ~ANonce, SNonce, ctr_plus_1, shareGTKData)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSharesGTK(~authThreadID, ~authID, ~PMK, shareGTKData)
      , ReadUnique(~pointerGTKState, ~authID) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
	[ AuthState(~authThreadID, 'REKEYNEGOTIATING', <~authID, ~PMK, ~suppThreadID, PTK, 
                ~ANonce, SNonce, ctr_plus_1, shareGTKData>)
    , !UsedCounterInGTKHandshake(~authThreadID, shareGTKData, ctr_plus_1) 
	, OutEnc(<!<rekeyMsg, MIC(PTK, rekeyMsg)>!>, ~authThreadID, ~messageID, 
             Auth_Rekey_GroupKey_Init_repeat, Auth) ]

OutEncRule(Auth_Rekey_GroupKey_Init_repeat, Auth)

rule Auth_Deauthenticate_Supplicant [color=a333ff]:
    [ AuthState(~authThreadID, 'REKEYNEGOTIATING', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr, shareGTKData>) ]
    --[ AuthenticatorDeauthenticatesSupplicant(~authThreadID, ~authID, ~PMK, ~suppThreadID, 
                                               shareGTKData)
      , AuthenticatorThreadFinishesGTKRekey(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                                       ~ANonce, SNonce, ctr, shareGTKData) ]->
    [ AuthState(~authThreadID, 'KEYERROR', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr, shareGTKData>)  ]

rule Auth_Rekey_GroupKey_Finished [color=a333ff]:
	let
        ctr = S(ctr_minus_1)
        ctr_response = S(ctr_response_minus_1)
		PTK = KDF(<PMK1, ANonce1, SNonce1>)
		shareGTK = GTK(~x)
        shareGTKNonce = <N('1'), ~authID>
        shareGTKData = <shareGTK, shareGTKNonce, $shareGTKIndex>
		suppResponse = <ctr_response, MIC(PTK, ctr_response)>
	in
	[ AuthState(~authThreadID, 'REKEYNEGOTIATING', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr, shareGTKData>)
	, InEnc(suppResponse, ~authThreadID, PTK, Auth)[no_precomp]
    , !UsedCounterInGTKHandshake(~authThreadID, shareGTKData, ctr_response)[-] ]
	--[ AuthenticatorThreadFinishesGTKRekey(~authThreadID, ~authID, ~PMK, ~suppThreadID, PTK, 
                                       ~ANonce, SNonce, ctr, shareGTKData) ]->
	[ AuthState(~authThreadID, 'PTK_INIT_DONE', 
                <~authID, ~PMK, ~suppThreadID, PTK, ~ANonce, SNonce, ctr>) ]

rule Auth_Install_GroupKey [color=ff9563]:
    let
        installedGTK = GTK(~x)
		installedGTKNonce = <N(n), ~authID>
        installedGTKData = <installedGTK, installedGTKNonce, 
                            $installedGTKIndex>
		shareGTK = GTK(~x)
        shareGTKNonce = <N('1'), ~authID>
        shareGTKData = <shareGTK, shareGTKNonce, $shareGTKIndex>
    in
    [ AuthInstallGTKCommand(~authID, shareGTKData)
    , !AuthGTKState(~authID, 'SETKEYS', installedGTKData, shareGTKData, 
                    ~oldPointerGTKState)[no_precomp]
    , AuthInstalledGTK(~authID, installedGTKData)[+]
    , Fr(~newPointerGTKState) ]
    --[ AuthenticatorInstalledGTK(~authID, shareGTKData)
      , AllocateUnique(~newPointerGTKState, ~authID)
      , Free(~oldPointerGTKState) ]->
    [ AuthInstalledGTK(~authID, shareGTKData)
    , !AuthGTKState(~authID, 'SETKEYS', shareGTKData, shareGTKData, 
                    ~newPointerGTKState) ]
    
// END Group-Key Handshake

// BEGIN WNM Sleep Mode (Message formats are described starting on page 1237
// and on page 1006)

rule Auth_Start_WNM_Sleep_Mode_Thread [color=ff7afd]:
    [ AuthStartWNMSleepModeThread(~authThreadID, ~authID, ~PMK, kNullPTK) ]
    --[ AuthenticatorStartsWNMSleepModeThread(~authThreadID, ~authID, ~PMK) ]->
    [ AuthWNMState(~authThreadID, 'WNM_STATE', ~authID, ~PMK) ]

// The following part of the standard (page 1624) is the reason why we don't 
// care about the state identifier of the AuthGTKState (i.e., why we just send 
// the latest GTK, no matter if it is already installed or not): If RSN is used 
// with management frame protection and a valid PTK is configured for the STA, 
// the current GTK and IGTK shall be included in the WNM Sleep Mode Response 
// frame. If a GTK/IGTK update is in progress, the pending GTK and IGTK shall 
// be included in the WNM Sleep Mode Response frame.
rule Auth_WNM_Accept_Awake_Request [color=ffb4fe]:
    let
        PTK = KDF(~PMK, ANonce, SNonce)
		shareGTK = GTK(~x)
        shareGTKNonce = <N(n), ~authID>
        shareGTKData = <shareGTK, shareGTKNonce, $shareGTKIndex>
        wnmAcceptMessage = <kAcceptAwake, shareGTKData>
        wnmRequestMessage = kRequestAwake
    in
    [ AuthWNMState(~authThreadID, 'WNM_STATE', ~authID, ~PMK) 
    , !AuthGTKState(~authID, stateIdentifier, installedGTKData, shareGTKData,
                    ~pointerGTKState)[no_precomp] 
    , InEnc(wnmRequestMessage, ~authThreadID, PTK, Auth)[no_precomp]
    , Fr(~messageID) ]
    --[ AuthenticatorAcceptsAwakeRequest(~authThreadID, ~authID)
      , AuthenticatorUsesGTK(~authID, installedGTKData, shareGTKData)
      , AuthenticatorSharesGTK(~authThreadID, ~authID, ~PMK, shareGTKData)
      , AuthenticatorAcceptsWNMRequest(~authThreadID, ~authID, ~PMK) 
      , AuthenticatorReceivesAwakeOK(~authThreadID, wnmAcceptMessage)
      , ReadUnique(~pointerGTKState, ~authID) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
    [ OutEnc(wnmAcceptMessage, ~authThreadID, ~messageID,
             Auth_WNM_Accept_Awake_Request, Auth)
    , AuthWNMState(~authThreadID, 'WNM_STATE', ~authID, ~PMK) ]

OutEncRule(Auth_WNM_Accept_Awake_Request, Auth, only_encrypted)


rule Auth_WNM_Accept_Sleep_Request [color=ffb4fe]:
    let
        wnmRequestSleepMessage = kRequestSleep
        wnmAcceptSleepMessage = kAcceptSleep
        PTK = KDF(~PMK, ANonce, SNonce)
    in
    [ AuthWNMState(~authThreadID, 'WNM_STATE', ~authID, ~PMK) 
    , !AuthReceiverPTK(~ptkID, ~authThreadID, ~authID, PTK, ~newPointerPTK)[no_precomp]
    , InEnc(wnmRequestSleepMessage, ~authThreadID, PTK, Auth)[no_precomp]
    , Fr(~messageID) ]
    --[ AuthenticatorAcceptsSleepRequest(~authThreadID, ~authID)
      , AuthenticatorAcceptsWNMRequest(~authThreadID, ~authID, ~PMK) 
      , AuthenticatorReceivesSleepOK(~authThreadID, wnmAcceptSleepMessage) 
      , EnqueueMessage(~authThreadID, ~messageID) ]->
    [ OutEnc(wnmAcceptSleepMessage, ~authThreadID, ~messageID,
             Auth_WNM_Accept_Sleep_Request, Auth)
    , AuthWNMState(~authThreadID, 'WNM_STATE', ~authID, ~PMK) ]

OutEncRule(Auth_WNM_Accept_Sleep_Request, Auth, only_encrypted)


rule Supp_Start_WNM_Sleep_Mode_Thread [color=87e1e6]:
    [ SuppStartWNMSleepModeThread(~suppThreadID, ~suppID, ~PMK, kNullPTK) ]
    --[ SupplicantStartsWNMSleepModeThread(~suppThreadID, ~suppID, ~PMK) ]->
    [ SuppWNMState(~suppThreadID, 'AWAKE', ~suppID, ~PMK) ]

rule Supp_Send_WNM_Sleep_Request [color=87e1e6]:
    let
        wnmRequestSleepMessage = kRequestSleep
    in
    [ SuppWNMState(~suppThreadID, 'AWAKE', ~suppID, ~PMK)
    , Fr(~messageID) ]
    --[ SupplicantRequestsSleep(~suppThreadID, ~suppID, ~PMK)
      , EnqueueMessage(~suppThreadID, ~messageID) ]->
    [ SuppWNMState(~suppThreadID, 'AWAIT_SLEEP_CONFIRMATION', 
                         ~suppID, ~PMK)
    , OutEnc(wnmRequestSleepMessage, ~suppThreadID, ~messageID,
             Supp_Send_WNM_Sleep_Request, Supp) ]

OutEncRule(Supp_Send_WNM_Sleep_Request, Supp, only_encrypted)

rule Supp_WNM_Receive_Sleep_Accept [color=87e1e6]:
    let
        PTK = KDF(~PMK, ANonce, SNonce)
        wnmAcceptSleepMessage = kAcceptSleep
    in
    [ SuppWNMState(~suppThreadID, 'AWAIT_SLEEP_CONFIRMATION', ~suppID, ~PMK)
   
    , !SuppReceiverPTK(~ptkID, ~suppThreadID, ~suppID, PTK, 
                       ~pointerRcvPTK)[no_precomp]
    , InEnc(wnmAcceptSleepMessage, ~suppThreadID, PTK, Supp)[no_precomp]
    , Fr(~nullGTKID)
    ifelse(INCLUDE_PATCHES, true, <!dnl
    , ReceiverGTK(~suppThreadID, ~oldGTKID, ~PMK,
                  oldGTK, oldGTKNonce, $oldIndex)!>,) ]
    --[ SupplicantStartsSleep(~suppThreadID, ~suppID, ~PMK)
      , Read(~pointerRcvPTK) ]->
    [ SuppWNMState(~suppThreadID, 'SLEEP', ~suppID, ~PMK)
    ifelse(INCLUDE_PATCHES, true <!dnl
    , ReceiverGTK(~suppThreadID, ~nullGTKID, ~PMK,
                  kNullGTK, kNullGTKNonce, kNullGTKIndex)!>,) ]

rule Supp_WNM_Send_Awake_Request [color=87e1e6]:
    let
        wnmRequestAwakeMessage = kRequestAwake
    in
    [ SuppWNMState(~suppThreadID, 'SLEEP', ~suppID, ~PMK)
    , Fr(~messageID) ]
    --[ SupplicantRequestsAwake(~suppThreadID, ~suppID, ~PMK) 
      , Enqueue(~suppThreadID, ~messageID) ]->
    [ SuppWNMState(~suppThreadID, 'AWAIT_AWAKE_CONFIRMATION', ~suppID, ~PMK)
    , OutEnc(wnmRequestAwakeMessage, ~suppThreadID, ~messageID,
             Supp_Send_WNM_Awake_Request, Supp) ]

OutEncRule(Supp_Send_WNM_Awake_Request, Supp, only_encrypted)

rule Supp_WNM_Receive_Awake_Accept [color=87e1e6]:
    let
        PTK = KDF(~PMK, ANonce, SNonce)
        newGTK = GTK(x)
        newGTKNonce = <N(n), authID>
        newGTKData = <newGTK, newGTKNonce, $newIndex>
        wnmAcceptWakeUpMessage = <kAcceptAwake, newGTKData>
    in
    [ SuppWNMState(~suppThreadID, 'AWAIT_AWAKE_CONFIRMATION', ~suppID, ~PMK)
    , !SuppReceiverPTK(~ptkID, ~suppThreadID, ~suppID, PTK, 
                       ~pointerRcvPTK)[no_precomp]
    , InEnc(wnmAcceptWakeUpMessage, ~suppThreadID, PTK, Supp)[no_precomp]
    , ReceiverGTK(~suppThreadID, ~oldGTKID, ~PMK,
                  oldGTK, oldGTKNonce, $oldIndex)
    , Fr(~newGTKID) ]
    --[ SupplicantAwakes(~suppThreadID, ~suppID, ~PMK)
      , SupplicantInstalledGTK(~newGTKID, ~suppThreadID, ~PMK,
                               newGTK, newGTKNonce, $newIndex)
      , SeesNonceForGTK(~newGTKID, ~suppThreadID, newGTK, newGTKNonce)
      , Read(~pointerRcvPTK)
      ifelse(INCLUDE_PATCHES, true, <!, Neq(oldGTK, newGTK)!>,) ]->
    [ SuppWNMState(~suppThreadID, 'AWAKE', ~suppID, ~PMK)
    , ReceiverGTK(~suppThreadID, ~newGTKID, ~PMK, 
                  newGTK, newGTKNonce, $newIndex) ]

// END WNM Sleep Mode

// BEGIN Lemmas (Helpers)

lemma nonce_reuse_key_type [sources]:
    "All key nonce #i. 
     NonceReuse(key, nonce) @ i 
     ==> ((Ex #j. j < i & KU(key) @ j) |
          (Ex x. key = GTK(x)) |
          (Ex PMK ANonce SNonce. key = KDF(<PMK, ANonce, SNonce>)))"

lemma associated_parties_need_to_be_created [reuse]:
    "All authID authThreadID suppID suppThreadID PMK #i.
     Associate(authID, authThreadID, suppID, suppThreadID, PMK) @ i
     ==> (Ex #j. j < i & AuthenticatorCreated(authID) @ j) &
         (Ex #k. k < i & SupplicantCreated(suppID) @ k)"

lemma association_of_authenticator_with_supplicant_is_unique [reuse]:
    "All authID1 authID2 authThreadID suppID1 suppID2 
         suppThreadID PMK1 PMK2 #i #j.
     Associate(authID1, authThreadID, suppID1, suppThreadID, PMK1) @ i &
     Associate(authID2, authThreadID, suppID2, suppThreadID, PMK2) @ j 
     ==> #i = #j"

lemma authenticator_used_ptks_must_be_installed 
      [reuse, use_induction, heuristic=S]:
    "All ptkID authID authThreadID ptkInstallerID PTK nonceNumber #i. 
     AuthEncryptedWithPTK(ptkID, authThreadID, authID,
                          PTK, <nonceNumber, ptkInstallerID>) @ i 
     ==> (Ex #j. j < i & 
          AuthInstalledPTK(ptkID, authThreadID, authID,
                           PTK, <kPTKNonceStartNumber, authID>)[+] @ j &
          authID = ptkInstallerID)"

lemma supplicant_used_ptks_must_be_installed
      [reuse, use_induction, heuristic=S]:
    "All ptkID suppID suppThreadID ptkInstallerID PTK nonceNumber #i. 
     SuppEncryptedWithPTK(ptkID, suppThreadID, suppID,
                          PTK, <nonceNumber, ptkInstallerID>) @ i 
     ==> (Ex PMK ANonce SNonce x #j. j < i & 
          SupplicantInstalledPTK(suppThreadID, suppID, PMK, ptkID, PTK, 
                                 <kPTKNonceStartNumber, suppID>, GTK(x), 
                                 ANonce, SNonce)[+] @ j &
          suppID = ptkInstallerID)"

lemma authenticator_use_gtk_must_be_preceded_by_install_gtk
      [reuse, use_induction, heuristic=S]:
    "All authID GTK n index shareGTKData #i.
     AuthenticatorUsesGTK(authID, <GTK, <n, authID>, index>, shareGTKData) @ i
     ==>
     Ex #j. AuthenticatorInstalledGTK(authID, <GTK, <N('1'), authID>, index>) @ j"

lemma authenticator_use_gtk_must_be_preceded_by_set_share_gtk
      [reuse, use_induction, heuristic=S]:
    "All authID GTK n index installedGTKData #i.
     AuthenticatorUsesGTK(authID, installedGTKData, 
                          <GTK, <n, authID>, index>) @ i
     ==>
     Ex #j. j < i & 
        AuthenticatorSetsShareGTK(authID, <GTK, <N('1'), authID>, index>) @ j"

lemma authenticator_gtk_rekey_must_be_preceded_by_create 
      [reuse, use_induction, heuristic=C]:
    "All authID installedGTKData shareGTKData newGTKData #i.
     AuthenticatorStartsGTKRekey(authID, installedGTKData, 
                                 shareGTKData, newGTKData) @ i
     ==> Ex #j. j < i & AuthenticatorCreated(authID) @ j"

lemma authenticator_encryption_gtks_must_be_installed 
      [reuse, use_induction, heuristic=C]:
    "All authID GTK n index shareGTKData #i. 
     EncryptedWithGTK(authID, <GTK, <n, authID>, index>, shareGTKData) @ i 
     ==> (Ex #j. j < i & 
          AuthenticatorInstalledGTK(authID, 
                                    <GTK, <N('1'), authID>, index>)[+] @ j)"

lemma authenticator_must_send_an_initial_m1 [reuse, use_induction]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i. 
     AuthenticatorSendsM1Again(authThreadID, authID, PMK, suppThreadID, PTK,
                               ANonce, SNonce, ctr) @ i
     ==> (Ex #j prectr. j < i & 
          AuthenticatorSendsM1(authThreadID, authID, PMK, suppThreadID, PTK,
                               ANonce, SNonce, prectr) @ j)"

lemma authenticator_snd_m1_is_unique_for_anonce [reuse]:
    "All authThreadID1 authThreadID2 authID1 authID2 PMK1 PMK2 
     suppThreadID1 suppThreadID2 PTK1 PTK2 ANonce SNonce1 SNonce2 ctr1 ctr2 #i #j.
     AuthenticatorSendsM1(authThreadID1, authID1, PMK1, suppThreadID1, PTK1,
                          ANonce, SNonce1, ctr1) @ i &
     AuthenticatorSendsM1(authThreadID2, authID2, PMK2, suppThreadID2, PTK2,
                          ANonce, SNonce2, ctr2) @ j 
     ==> #i = #j"

lemma supplicant_must_receive_an_initial_m1
      [reuse, use_induction, heuristic=S]:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr #i. 
     SupplicantReceivesM1Again(suppThreadID, suppID, PMK, authThreadID, PTK, 
                               GTK, ANonce, SNonce, ctr) @ i 
     ==> (Ex prectr #j. j < i & 
          SupplicantReceivesM1(suppThreadID, suppID, PMK, authThreadID, PTK,
                               GTK, ANonce, SNonce, prectr) @ j)"

lemma authenticator_snd_m1_precedes_rcv_m2 [reuse, use_induction, heuristic=C]:
    "All authThreadID authID PMK suppThreadID PTK ANonce oldSNonce SNonce ctr1 ctr2 #i #j.
     AuthenticatorSendsM1Again(authThreadID, authID, PMK, suppThreadID, PTK,
                               ANonce, oldSNonce, ctr1) @ i &
     AuthenticatorReceivesM2(authThreadID, authID, PMK, suppThreadID, PTK,
                             ANonce, SNonce, ctr2) @ j
     ==> i < j"

lemma authenticator_must_receive_an_initial_m2 
      [reuse, use_induction, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i. 
     AuthenticatorReceivesM2Again(authThreadID, authID, PMK, suppThreadID, PTK, 
                                  ANonce, SNonce, ctr) @ i
     ==> (Ex #j. j < i & 
          AuthenticatorReceivesM2(authThreadID, authID, PMK, suppThreadID, PTK,
                                  ANonce, SNonce, ctr) @ j)"

lemma authenticator_rcv_m2_must_be_preceded_by_snd_m1 [reuse, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i.
     AuthenticatorReceivesM2(authThreadID, authID, PMK, suppThreadID, PTK,
                             ANonce, SNonce, ctr) @ i
     ==> (Ex oldSNonce prectr #j. j < i &
          AuthenticatorSendsM1(authThreadID, authID, PMK, suppThreadID, PTK,
                               ANonce, oldSNonce, prectr) @ j)"

lemma authenticator_rcv_m2_is_unique_for_anonce [reuse, heuristic=C]:
    "All authThreadID1 authThreadID2 authID1 authID2 PMK1 PMK2 
     suppThreadID1 suppThreadID2 PTK1 PTK2 ANonce SNonce1 SNonce2 ctr1 ctr2 #i #j.
     AuthenticatorReceivesM2(authThreadID1, authID1, PMK1, suppThreadID1, PTK1,
                             ANonce, SNonce1, ctr1) @ i &
     AuthenticatorReceivesM2(authThreadID2, authID2, PMK2, suppThreadID2, PTK2,
                             ANonce, SNonce2, ctr2) @ j
     ==> #i = #j"

lemma authenticator_must_send_an_initial_m3
      [reuse, use_induction, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i. 
     AuthenticatorSendsM3Again(authThreadID, authID, PMK, suppThreadID, PTK,
                               ANonce, SNonce, ctr) @ i
     ==> (Ex prectr #j. j < i & 
          AuthenticatorSendsInitialM3(authThreadID, authID, PMK, suppThreadID, 
                                      PTK, ANonce, SNonce, prectr) @ j)"

lemma authenticator_rercv_m2_precedes_snd_m3
      [reuse, use_induction, heuristic=C]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr1 ctr2 #i #j.
     AuthenticatorReceivesM2Again(authThreadID, authID, PMK, suppThreadID, PTK, 
                                  ANonce, SNonce, ctr1) @ i &
     AuthenticatorSendsInitialM3(authThreadID, authID, PMK, suppThreadID, PTK,
                                 ANonce, SNonce, ctr2) @ j
     ==> #i < #j"

lemma authenticator_snd_m3_is_unique_for_anonce [reuse, heuristic=S]:
    "All authThreadID1 authThreadID2 authID1 authID2 PMK1 PMK2 
     suppThreadID1 suppThreadID2 PTK1 PTK2 ANonce SNonce1 SNonce2 ctr1 ctr2 #i #j.
     AuthenticatorSendsInitialM3(authThreadID1, authID1, PMK1, suppThreadID1, 
                                 PTK1, ANonce, SNonce1, ctr1) @ i &
     AuthenticatorSendsInitialM3(authThreadID2, authID2, PMK2, suppThreadID2, 
                                 PTK2, ANonce, SNonce2, ctr2) @ j 
     ==> #i = #j"

lemma supplicant_rercv_m1_precedes_rcv_m3 [use_induction, reuse, heuristic=S]:
    "All suppThreadID suppID PMK authThreadID PTK ANonce SNonce 
     GTK1 GTK2 ctr2 ctr1 #i #j.
     SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID, PTK, 
                          GTK1, ANonce, SNonce, ctr2) @ j &
     SupplicantReceivesM1Again(suppThreadID, suppID, PMK, authThreadID, PTK, 
                               GTK2, ANonce, SNonce, ctr1) @ i 
     ==> i < j"

lemma supplicant_rercv_m3_or_gtk_rekey_must_be_preceded_by_rcv_m3
    [reuse, use_induction, heuristic=S]:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr #i. 
     SuppRcvM3AgainOrGroupRekey(suppThreadID, suppID, PMK, authThreadID, PTK,
                                GTK, ANonce, SNonce, ctr) @ i
     ==> (Ex prectr ANonce1 SNonce1 PMK1 x #j. j < i &
          SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID,
                               KDF(PMK1, ANonce1, SNonce1), GTK(x), 
                               ANonce, SNonce, prectr) @ j)"

lemma supplicant_rcv_m1_must_be_preceded_by_associate
    [reuse, use_induction, heuristic=C]:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr #i. 
     SupplicantReceivesM1(suppThreadID, suppID, PMK, authThreadID, PTK, GTK,
                          ANonce, SNonce, ctr) @ i 
     ==> (Ex authID #j. j < i & 
          Associate(authID, authThreadID, suppID, suppThreadID, PMK) @ j)"

lemma supplicant_rcv_m3_must_be_preceded_by_associate [reuse, heuristic=S]:
    "All suppThreadID suppID PMK authThreadID PTK ANonce SNonce GTK ctr #i.
     SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID, PTK, 
                          ANonce, SNonce, GTK, ctr) @ i
     ==> (Ex authID #j.
          Associate(authID, authThreadID, suppID, suppThreadID, PMK) @ j)"
    
lemma supplicant_initial_rcv_m3_is_unique_for_snonce [reuse, heuristic=S]:
    "All suppThreadID1 suppThreadID2 suppID1 suppID2 PMK 
     authThreadID1 authThreadID2 PTK1 PTK2 ANonce1 ANonce2 SNonce 
     GTK1 GTK2 ctr1 ctr2 #i #j.
     SupplicantReceivesM3(suppThreadID1, suppID1, PMK, authThreadID1, PTK1, GTK1,
                          ANonce1, SNonce, ctr1) @ i &
     SupplicantReceivesM3(suppThreadID2, suppID2, PMK, authThreadID2, PTK2, GTK2,
                          ANonce2, SNonce, ctr2) @ j
     ==> #i = #j"

lemma supplicant_rercv_m3_or_gtk_rekey_must_be_preceded_by_send_m4
    [reuse, use_induction, heuristic=C]:
    "All suppThreadID suppID PMK authThreadID PTK ANonce SNonce GTK ctr  #i. 
     SuppRcvM3AgainOrGroupRekey(suppThreadID, suppID, PMK, authThreadID, PTK,
                                GTK, ANonce, SNonce, ctr) @ i 
     ==> (Ex x #j. j < i &
          SupplicantSendsM4(suppThreadID, suppID, PMK, authThreadID, PTK,
                            GTK(x),  ANonce, SNonce) @ j)"

lemma supplicant_send_m4_must_be_preceded_by_rcv_m3
    [reuse, use_induction, heuristic=S]:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce #i. 
     SupplicantSendsM4(suppThreadID, suppID, PMK, authThreadID, PTK, GTK, 
                       ANonce, SNonce) @ i 
     ==> (Ex prectr PMK1 ANonce1 SNonce1 x #j. j < i &
          SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID,
                               KDF(<PMK1, ANonce1, SNonce1>), GTK(x),
                               ANonce, SNonce, prectr) @ j)"

lemma authenticator_snd_m3_rpt_precedes_rcv_m4
      [reuse, use_induction, heuristic=C]:
    "All authThreadID authID PMK suppThreadID PTK1 PTK2 ANonce SNonce ctr1 ctr2 #i #j.
     AuthenticatorSendsM3Again(authThreadID, authID, PMK, suppThreadID, PTK1, 
                               ANonce, SNonce, ctr1) @ i &
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK2,
                            ANonce, SNonce, ctr2) @ j 
     ==> #i < #j"

lemma authenticator_installed_is_unique_for_anonce [reuse, heuristic=S]:
    "All authThreadID1 authThreadID2 authID1 authID2 PMK1 PMK2 
         suppThreadID1 suppThreadID2 PTK1 PTK2 ANonce SNonce1 SNonce2 
         ctr1 ctr2 #i #j.
     AuthenticatorInstalled(authThreadID1, authID1, PMK1, suppThreadID1, PTK1, 
                            ANonce, SNonce1, ctr1) @ i &
     AuthenticatorInstalled(authThreadID2, authID2, PMK2, suppThreadID2, PTK2, 
                            ANonce, SNonce2, ctr2) @ j 
     ==> #i = #j"

lemma authenticator_wnm_sleep_thread_is_unique [reuse, heuristic=S]:
    "All authThreadID authID1 authID2 PMK #i #j.
     AuthenticatorStartsWNMSleepModeThread(authThreadID, authID1, PMK) @ i &
     AuthenticatorStartsWNMSleepModeThread(authThreadID, authID2, PMK) @ j
     ==> #i = #j"

lemma supplicant_wnm_sleep_thread_is_unique [reuse, heuristic=S]:
    "All suppThreadID suppID1 suppID2 PMK #i #j.
     SupplicantStartsWNMSleepModeThread(suppThreadID, suppID1, PMK) @ i &
     SupplicantStartsWNMSleepModeThread(suppThreadID, suppID2, PMK) @ j
     ==> #i = #j"

lemma authenticator_gtk_init_again_must_be_preceded_by_init
      [reuse, use_induction, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr newGTK #i. 
     AuthenticatorInitsGroupKeyRekeyAgain(authThreadID, authID, PMK, suppThreadID,
                                          PTK, ANonce, SNonce, ctr, newGTK) @ i
     ==> (Ex prectr #j. j < i & 
          AuthenticatorInitsGroupKeyRekey(authThreadID, authID, PMK, suppThreadID,
                                          PTK, ANonce, SNonce, prectr, newGTK) @ j)" 

lemma authenticator_gtk_init_must_be_preceded_by_installed
      [reuse, use_induction, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr newGTK #i. 
     AuthenticatorInitsGroupKeyRekey(authThreadID, authID, PMK, suppThreadID, PTK, 
                                     ANonce, SNonce, ctr, newGTK) @ i
     ==> (Ex prectr #j. j < i & 
          AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK, 
                                 ANonce, SNonce, prectr) @ j)" 

lemma authenticator_gtk_rekey_finished_must_be_preceded_by_init [reuse]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr shareGTK #i. 
     AuthenticatorThreadFinishesGTKRekey(authThreadID, authID, PMK, suppThreadID,
                                         PTK, ANonce, SNonce, ctr, shareGTK) @ i
     ==> (Ex prectr #j. j < i & 
          AuthenticatorInitsGroupKeyRekey(authThreadID, authID, PMK, suppThreadID,
                                          PTK, ANonce, SNonce, prectr, shareGTK) @ j)" 

lemma authenticator_gtk_rekey_must_be_preceded_by_send_initial_m3
      [reuse, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce newGTK  ctr #i. 
     AuthenticatorThreadFinishesGTKRekey(authThreadID, authID, PMK, suppThreadID,
                                         PTK, ANonce, SNonce, ctr, newGTK) @ i
     ==> (Ex PMK1 ANonce1 SNonce1 prectr #j. j < i & 
          AuthenticatorSendsInitialM3(authThreadID, authID, PMK, suppThreadID,
                                      KDF(PMK1, ANonce1, SNonce1), ANonce, 
                                      SNonce, prectr) @ j)"

lemma authenticator_installed_must_be_preceded_by_send_initial_m3
      [reuse, use_induction, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i. 
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK,
                            ANonce, SNonce, ctr) @ i 
     ==> (Ex prePTK prectr #j. j < i & 
          AuthenticatorSendsInitialM3(authThreadID, authID, PMK, suppThreadID, 
                                      prePTK, ANonce, SNonce, prectr) @ j)"

lemma authenticator_installed_must_be_preceded_by_associate
      [reuse, use_induction, heuristic=S]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i. 
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK,
                            ANonce, SNonce, ctr) @ i 
     ==> (Ex suppID #j. j < i & 
          Associate(authID, authThreadID, suppID, suppThreadID, PMK) @ j)"

lemma only_one_supplicant_can_be_installed_for_a_pmk [reuse, heuristic=C]:
     "All suppThreadID1 suppThreadID2 suppID1 suppID2 GTK1 GTK2 PMK 
      ptkID1 ptkID2 PTK1 PTK2 ptkNonce1 ptkNonce2 ANonce1 ANonce2 
      SNonce1 SNonce2 #i #j.
      SupplicantInstalledPTK(suppThreadID1, suppID1, PMK, ptkID1, PTK1, 
                             ptkNonce1, GTK1, ANonce1, SNonce1) @ i & 
      SupplicantInstalledPTK(suppThreadID2, suppID2, PMK, ptkID2, PTK2, 
                             ptkNonce2, GTK2, ANonce2, SNonce2) @ j
      ==> suppThreadID1 = suppThreadID2" 

lemma supplicant_wnm_sleep_thread_has_to_start
      [use_induction, reuse, heuristic=S]:
    "All suppThreadID suppID PMK #i. 
     SupplicantStartsSleep(suppThreadID, suppID, PMK) @ i
     ==> Ex #j. j < i & 
         SupplicantStartsWNMSleepModeThread(suppThreadID, suppID, PMK) @ j"

lemma authenticator_wnm_sleep_thread_has_to_start 
      [use_induction, reuse, heuristic=S]:
    "All authThreadID authID PMK #i. 
     AuthenticatorAcceptsWNMRequest(authThreadID, authID, PMK) @ i
     ==> Ex #j. j < i & 
         AuthenticatorStartsWNMSleepModeThread(authThreadID, authID, PMK) @ j"

lemma pmks_are_secret_unless_revealed [reuse]:
    "All authID authThreadID suppID suppThreadID PMK #i #j.
     Associate(authID, authThreadID, suppID, suppThreadID, PMK) @ i &
     K(PMK) @ j ==>
     Ex #k. k < j & RevealPMK(PMK) @ k"

lemma pmks_are_ku_secret_unless_revealed [reuse]:
    "All authID authThreadID suppID suppThreadID PMK #i #j.
     Associate(authID, authThreadID, suppID, suppThreadID, PMK) @ i &
     KU(PMK) @ j ==> Ex #k. k < j & RevealPMK(PMK) @ k"

ifelse(INCLUDE_PATCHES, true, <!

lemma supplicant_ptk_installation_is_unique_for_ptk [reuse, heuristic=S]:
    "All suppThreadID1 suppThreadID2 suppID1 suppID2 PMK PTK ptkID1 ptkID2 
     GTK1 GTK2 ptkNonce1 ptkNonce2 ANonce1 ANonce2 SNonce1 SNonce2 #i #j.
     SupplicantInstalledPTK(suppThreadID1, suppID1, PMK, PTK, ptkID1, 
                            ptkNonce1, GTK1, ANonce1, SNonce1) @ i & 
     SupplicantInstalledPTK(suppThreadID2, suppID2, PMK, PTK, ptkID2, 
                            ptkNonce2, GTK2, ANonce2, SNonce2) @ j
     ==> #i = #j" 

lemma authenticator_ptk_installation_is_unique_for_ptk [reuse, heuristic=S]:
    "All authThreadID1 authThreadID2 authID1 authID2 PMK 
     suppThreadID1 suppThreadID2 PTK ANonce1 ANonce2 SNonce1 SNonce2 
     ctr1 ctr2 #i #j.
     AuthenticatorInstalled(authThreadID1, authID1, PMK, suppThreadID1, PTK, 
                            ANonce1, SNonce1, ctr1) @ i & 
     AuthenticatorInstalled(authThreadID2, authID2, PMK, suppThreadID2, PTK,
                            ANonce2, SNonce2, ctr2) @ j
     ==> #i = #j" 

lemma ptk_nonce_must_use_sender_id [reuse, heuristic=C]:
    "All keyID senderThreadID senderID PTK ctr installerID #i.
     EncryptedWithPTK(keyID, senderThreadID, senderID, 
                      PTK, <ctr, installerID>) @ i
     ==> senderID = installerID"

lemma different_ptk_id_must_have_different_ptk_nonce_pairs
      [reuse, heuristic=S]:
    "All keyID1 keyID2 senderID1 senderID2 senderThreadID1 senderThreadID2 
     PTK installerID ctr #i #j. 
     EncryptedWithPTK(keyID1, senderThreadID1, senderID1,
                      PTK, <ctr, installerID>)[+] @ i &
     EncryptedWithPTK(keyID2, senderThreadID2, senderID2,
                      PTK, <ctr, installerID>)[+] @ j 
     ==> keyID1 = keyID2"

lemma authenticator_and_supplicant_have_different_ptk_nonce_pairs
      [reuse, heuristic=S]:
    "All keyID1 keyID2 authID suppID authThreadID suppThreadID 
     PTK n keyInstallerID #i #j. 
     SuppEncryptedWithPTK(keyID1, suppThreadID, suppID,
                          PTK, <n, keyInstallerID>)[+] @ i &
     AuthEncryptedWithPTK(keyID2, authThreadID, authID,
                          PTK, <n, keyInstallerID>)[+] @ j
     ==> F"

lemma authenticator_ptk_nonce_pair_is_unique 
      [reuse, use_induction, heuristic=S]:
    "All keyID1 keyID2 authID1 authID2 authThreadID1 authThreadID2 
     PTK n keyInstallerID #i #j. i < j &
     AuthEncryptedWithPTK(keyID1, authThreadID1, authID1,
                          PTK, <n, keyInstallerID>)[+] @ i &
     AuthEncryptedWithPTK(keyID2, authThreadID2, authID2,
                          PTK, <n, keyInstallerID>)[+] @ j
     ==> F"

lemma supplicant_ptk_nonce_pair_is_unique 
      [reuse, use_induction, heuristic=S,
       hide_lemma=supplicant_used_ptks_must_be_installed]:
    "All keyID1 keyID2 suppID1 suppID2 suppThreadID1 suppThreadID2 
     PTK n keyInstallerID #i #j. i < j &
     SuppEncryptedWithPTK(keyID1, suppThreadID1, suppID1,
                          PTK, <n, keyInstallerID>)[+] @ i &
     SuppEncryptedWithPTK(keyID2, suppThreadID2, suppID2,
                          PTK, <n, keyInstallerID>)[+] @ j
     ==> F"

lemma ptk_nonce_pair_is_unique [reuse, heuristic=S]:
    "All keyID1 keyID2 senderID1 senderID2 senderThreadID1 senderThreadID2 
         PTK nonce #i #j. 
     EncryptedWithPTK(keyID1, senderThreadID1, senderID1, PTK, nonce)[+] @ i &
     EncryptedWithPTK(keyID2, senderThreadID2, senderID2, PTK, nonce)[+] @ j
     ==> #i = #j"

// END Lemmas (Helpers)

// BEGIN Main Statements

lemma supplicant_ptk_is_secret [heuristic=S, reuse]:
    "All suppThreadID suppID PMK ptkID PTK ptkNonce GTK ANonce SNonce #i. 
     SupplicantInstalledPTK(suppThreadID, suppID, PMK, ptkID, PTK, ptkNonce, 
                            GTK, ANonce, SNonce) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. K(PTK)[+] @ k)"

lemma supplicant_ptk_is_ku_secret [heuristic=S, reuse]:
    "All suppThreadID suppID PMK ANonce SNonce ptkID ptkNonce PTK GTK #i. 
     SupplicantInstalledPTK(suppThreadID, suppID, PMK, ptkID, PTK, ptkNonce,
                            GTK, ANonce, SNonce) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. KU(PTK)[+] @ k)"

lemma supplicant_preliminary_ptk_is_secret [heuristic=S, reuse]:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr #i. 
     SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID, PTK, GTK,
                          ANonce, SNonce, ctr) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. K(KDF(PMK, ANonce, SNonce))[+] @ k)"

lemma supplicant_preliminary_ptk_is_ku_secret [heuristic=S, reuse]:
    "All suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr #i. 
     SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID, PTK, GTK,
                          ANonce, SNonce, ctr) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. KU(KDF(PMK, ANonce, SNonce))[+] @ k)"

lemma authenticator_ptk_is_secret [heuristic=S, reuse]:
    "All authThreadID authID PMK suppThreadID PTK ANonce SNonce ctr #i. 
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK, 
                            ANonce, SNonce, ctr) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. K(PTK)[+] @ k)"

lemma authenticator_ptk_is_ku_secret [heuristic=S, reuse]:
    "All authThreadID authID PMK suppThreadID ANonce SNonce PTK ctr #i. 
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK, 
                            ANonce, SNonce, ctr) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. KU(PTK)[+] @ k)"

lemma authenticator_preliminary_ptk_is_secret [reuse, heuristic=S]:
    "All authThreadID authID PMK suppThreadID oldPTK ANonce SNonce ctr #i. 
     AuthenticatorSendsInitialM3(authThreadID, authID, PMK, suppThreadID, 
                                 oldPTK, ANonce, SNonce, ctr) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. K(KDF(PMK, ANonce, SNonce))[+] @ k)"

lemma authenticator_preliminary_ptk_is_ku_secret [reuse, heuristic=S]:
    "All authThreadID authID PMK suppThreadID oldPTK ANonce SNonce ctr #i. 
     AuthenticatorSendsInitialM3(authThreadID, authID, PMK, suppThreadID, oldPTK, 
                                 ANonce, SNonce, ctr) @ i &
     not (Ex #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. KU(KDF(PMK, ANonce, SNonce))[+] @ k)"

// Provable manually
lemma authenticator_authentication [heuristic=S]:
    "All authThreadID suppThreadID PMK ANonce SNonce PTK #i. 
     AuthenticatorCommit(authThreadID, suppThreadID, 
                         PMK, ANonce, SNonce, PTK) @ i &
     not (Ex #r. RevealPMK(PMK) @ r)
     ==> Ex #j. j < i &
     SupplicantRunning(suppThreadID, authThreadID, PMK, ANonce, SNonce, PTK) @ j"

// Provable manually
lemma supplicant_authentication [heuristic=S]:
    "All suppThreadID authThreadID PMK ANonce SNonce PTK #i. 
     SupplicantCommit(suppThreadID, authThreadID, 
                      PMK, ANonce, SNonce, PTK) @ i &
     not (Ex #r. RevealPMK(PMK) @ r)
     ==> Ex #j. j < i &
                AuthenticatorRunning(authThreadID, suppThreadID, 
                                     PMK, ANonce, SNonce, PTK) @ j"

lemma helper_authenticator_gtk_installation_is_unique_for_gtk 
      [reuse, heuristic=C]:
    "All authID groupKey n index1 index2 #i #j.
     AuthenticatorInstalledGTK(authID, 
                               <groupKey, <N(n), authID>, index1>)[+] @ i &
     AuthenticatorInstalledGTK(authID,
                               <groupKey, <N(n), authID>, index2>)[+] @ j &
     i < j ==> F" 

lemma authenticator_gtk_installation_is_unique_for_gtk [reuse, heuristic=S]:
    "All authID groupKey n index1 index2 #i #j.
     AuthenticatorInstalledGTK(authID, <groupKey, <N(n), authID>, index1>) @ i &
     AuthenticatorInstalledGTK(authID, <groupKey, <N(n), authID>, index2>) @ j
     ==> #i = #j" 

lemma gtk_encryption_nonces_increase_strictly_over_time 
      [reuse, use_induction, heuristic=S]:
    "All authID GTK m n index1 index2 shareGTKData1 shareGTKData2 #i #j.
     EncryptedWithGTK(authID, <GTK, <N(n), authID>, index1>, shareGTKData1)[+] @ i &
     EncryptedWithGTK(authID, <GTK, <N(m), authID>, index2>, shareGTKData2)[+] @ j &
     i < j
     ==> Ex z. m = n + z"

lemma gtk_nonce_pair_is_unique [reuse, use_induction, heuristic=S]:
    "All authID1 authID2 GTK nonce index1 index2 shareGTKData1 shareGTKData2 #i #j. 
     EncryptedWithGTK(authID1, <GTK, nonce, index1>, shareGTKData1)[+] @ i &
     EncryptedWithGTK(authID2, <GTK, nonce, index2>, shareGTKData2)[+] @ j
     ==> #i = #j"

lemma no_nonce_reuse_for_installed_gtk [reuse, heuristic=s]:
    "All authID groupKey initialNonce index #i.
     AuthenticatorInstalledGTK(authID, <groupKey, initialNonce, index>) @ i &
     not(Ex PMK #j. RevealPMK(PMK) @ j)
     ==> not Ex nonce #j. NonceReuse(groupKey, nonce) @ j"

lemma authenticator_gtk_is_secret [heuristic=S, reuse]:
    "All authID GTK nonce index #i. 
     AuthenticatorInstalledGTK(authID, <GTK, nonce, index>) @ i &
     not(Ex PMK #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. K(GTK)[+] @ k)"

lemma authenticator_gtk_is_ku_secret [heuristic=S, reuse]:
    "All authID GTK nonce index #i. 
     AuthenticatorInstalledGTK(authID, <GTK, nonce, index>) @ i &
     not(Ex PMK #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. KU(GTK)[+] @ k)"

lemma authenticator_sets_share_gtk_is_secret 
      [heuristic=S, reuse,
       hide_lemma=authenticator_use_gtk_must_be_preceded_by_install_gtk,
       hide_lemma=authenticator_use_gtk_must_be_preceded_by_set_share_gtk,
       hide_lemma=authenticator_gtk_rekey_must_be_preceded_by_create,
       hide_lemma=authenticator_encryption_gtks_must_be_installed,
       hide_lemma=authenticator_gtk_is_secret,
       hide_lemma=authenticator_gtk_is_ku_secret,
       hide_lemma=authenticator_preliminary_ptk_is_secret,
       hide_lemma=authenticator_ptk_is_secret
       ]:
    "All authID GTK nonce index #i. 
     AuthenticatorSetsShareGTK(authID, <GTK, nonce, index>) @ i &
     (not Ex #l. AuthenticatorInstalledGTK(authID, <GTK, nonce, index>) @ l) &
     not(Ex PMK1 #j. RevealPMK(PMK1) @ j)
     ==> not(Ex #k. K(GTK)[+] @ k)"

lemma authenticator_sets_share_gtk_is_ku_secret 
      [heuristic=S, reuse, 
       hide_lemma=authenticator_use_gtk_must_be_preceded_by_install_gtk,
       hide_lemma=authenticator_use_gtk_must_be_preceded_by_set_share_gtk,
       hide_lemma=authenticator_gtk_rekey_must_be_preceded_by_create,
       hide_lemma=authenticator_encryption_gtks_must_be_installed,
       hide_lemma=authenticator_gtk_is_secret,
       hide_lemma=authenticator_gtk_is_ku_secret,
       hide_lemma=authenticator_preliminary_ptk_is_secret,
       hide_lemma=authenticator_ptk_is_secret ]:
    "All authID GTK nonce index #i. 
     AuthenticatorSetsShareGTK(authID, <GTK, nonce, index>) @ i &
     (not Ex #l. AuthenticatorInstalledGTK(authID, <GTK, nonce, index>) @ l) &
     not(Ex PMK1 #j. RevealPMK(PMK1) @ j)
     ==> not(Ex #k. KU(GTK)[+] @ k)"

lemma authenticator_shared_gtk_is_ku_secret [heuristic=S, reuse]:
    "All authThreadID authID PMK GTK nonce index #i. 
     AuthenticatorSharesGTK(authThreadID, authID, PMK, 
                            <GTK, nonce, index>) @ i &
     not(Ex PMK1 #j. RevealPMK(PMK1) @ j)
     ==> not(Ex #k. KU(GTK)[+] @ k)"

lemma supplicant_gtk_installation_is_unique_for_gtk_id [heuristic=S, reuse,
       hide_lemma=supplicant_preliminary_ptk_is_secret,
       hide_lemma=authenticator_shared_gtk_is_ku_secret,
       hide_lemma=authenticator_shared_gtk_is_secret,
       hide_lemma=authenticator_sets_share_gtk_is_secret,
       hide_lemma=authenticator_sets_share_gtk_is_ku_secret,
       hide_lemma=authenticator_gtk_is_secret,
       hide_lemma=authenticator_gtk_is_ku_secret,
       hide_lemma=no_nonce_reuse_for_installed_gtk]:
   "All gtkID suppThreadID1 PMK1 GTK1 n1 index1 authID1 
              suppThreadID2 PMK2 GTK2 n2 index2 authID2 #i #j.
    SupplicantInstalledGTK(gtkID, suppThreadID1, PMK1, 
                           GTK1, <N(n1), authID1>, index1) @ i &
    SupplicantInstalledGTK(gtkID, suppThreadID2, PMK2, 
                           GTK2, <N(n2), authID2>, index2) @ j
    ==> #i = #j"

lemma supplicant_receiver_gtk_must_be_installed 
      [reuse, use_induction, heuristic=S]:
   "All keyID suppThreadID PMK GTK n authID #i.
    ReceiveGTKEncryptedPayload(keyID, suppThreadID, PMK, 
                                GTK, <N(n), authID>) @ i
    ==> Ex m index #j. #j < #i &
        SupplicantInstalledGTK(keyID, suppThreadID, PMK, 
                               GTK, <N(m), authID>, index) @ j"

// Provable manually and possibly also automatically.
// Most cases of the proof are straightforward.
// However, one case is that the supplicant installs the GTK
// because it received a WNM Awake Accept message. In this case,
// first ask where the SuppReceiverPTK comes from. Then, 
// use the lemma that says the PTK (KDF(PMK, ANonce, SNonce)) is secret 
// (unless revealed). After this, ask where the Awake Accept message comes
// from (both the In_Supp fact and the KU fact). Finally, just ask for 
// the start of the authenticator's WNM thread (AuthStartWNMSleepModeThread).
lemma supplicant_gtk_installation_means_auth_sent_gtk 
      [reuse, heuristic=C,
       hide_lemma=supplicant_preliminary_ptk_is_secret,
       hide_lemma=authenticator_shared_gtk_is_ku_secret,
       hide_lemma=authenticator_shared_gtk_is_secret,
       hide_lemma=authenticator_sets_share_gtk_is_secret,
       hide_lemma=authenticator_sets_share_gtk_is_ku_secret,
       hide_lemma=authenticator_gtk_is_secret,
       hide_lemma=authenticator_gtk_is_ku_secret,
       hide_lemma=no_nonce_reuse_for_installed_gtk]:
    "All suppThreadID gtkID PMK authID GTK n index #i.
     SupplicantInstalledGTK(gtkID, suppThreadID, PMK,
                            GTK, <N(n), authID>, index) @ i &
     not (Ex #k. RevealPMK(PMK) @ k)
     ==> 
     Ex authID authThreadID #j. j < i &
     AuthenticatorSharesGTK(authThreadID, authID, PMK,
                            <GTK, <N(n), authID>, index>) @ j"

lemma supplicant_gtk_is_secret [heuristic=S, reuse]:
    "All suppThreadID gtkID PMK authID GTK n index #i.
     SupplicantInstalledGTK(gtkID, suppThreadID, PMK,
                            GTK, <N(n), authID>, index) @ i &
     not(Ex PMK #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. K(GTK)[+] @ k)"

lemma supplicant_gtk_is_ku_secret [heuristic=S, reuse]:
    "All suppThreadID gtkID PMK authID GTK n index #i.
     SupplicantInstalledGTK(gtkID, suppThreadID, PMK,
                            GTK, <N(n), authID>, index) @ i &
     not(Ex PMK #j. RevealPMK(PMK) @ j)
     ==> not(Ex #k. KU(GTK)[+] @ k)"

!>,)

// END Main Statements

// BEGIN Sanity Checks

define(hide_unwanted_lemmas,
<!
    hide_lemma=supplicant_gtk_installation_means_auth_sent_gtk,
    hide_lemma=supplicant_receiver_gtk_must_be_installed,
    hide_lemma=pmks_are_secret_unless_revealed,
    hide_lemma=pmks_are_ku_secret_unless_revealed,
    hide_lemma=authenticator_used_ptks_must_be_installed,
    hide_lemma=supplicant_used_ptks_must_be_installed,
    hide_lemma=authenticator_use_gtk_must_be_preceded_by_install_gtk,
    hide_lemma=authenticator_use_gtk_must_be_preceded_by_set_share_gtk,
    hide_lemma=authenticator_gtk_rekey_must_be_preceded_by_create,
    hide_lemma=authenticator_encryption_gtks_must_be_installed,
    hide_lemma=supplicant_ptk_is_secret,
    hide_lemma=supplicant_ptk_is_ku_secret,
    hide_lemma=supplicant_preliminary_ptk_is_secret,
    hide_lemma=supplicant_preliminary_ptk_is_ku_secret,
    hide_lemma=supplicant_gtk_is_secret,
    hide_lemma=supplicant_gtk_is_ku_secret,
    hide_lemma=authenticator_ptk_is_secret,
    hide_lemma=authenticator_ptk_is_ku_secret,
    hide_lemma=authenticator_preliminary_ptk_is_secret,
    hide_lemma=authenticator_preliminary_ptk_is_ku_secret,
    hide_lemma=no_nonce_reuse_for_installed_gtk,
    hide_lemma=authenticator_shared_gtk_is_ku_secret,
    hide_lemma=authenticator_shared_gtk_is_secret,
    hide_lemma=authenticator_sets_share_gtk_is_secret,
    hide_lemma=authenticator_sets_share_gtk_is_ku_secret,
    hide_lemma=authenticator_use_gtk_must_be_preceded_by_set_share_gtk,
    hide_lemma=authenticator_gtk_is_secret,
    hide_lemma=authenticator_gtk_is_ku_secret !>)

lemma supplicant_can_wake_up [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK #i. 
     SupplicantAwakes(suppThreadID, suppID, PMK) @ i"

lemma supplicant_can_request_sleep
      [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK #i. 
     SupplicantRequestsSleep(suppThreadID, suppID, PMK) @ i"

lemma supplicant_can_start_wnm_thread
      [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK #i. 
     SupplicantStartsWNMSleepModeThread(suppThreadID, suppID, PMK) @ i"

lemma supplicant_can_rcv_m1 [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK authThreadID PTK GTK ANonce SNonce ctr #i.
     SupplicantReceivesM1(suppThreadID, suppID, PMK, authThreadID, PTK, GTK, 
                          ANonce, SNonce, ctr) @ i"

lemma supplicant_can_rcv_m3 [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK authThreadID GTK PTK ANonce SNonce ctr #i.
     SupplicantReceivesM3(suppThreadID, suppID, PMK, authThreadID, PTK, 
                          ANonce, SNonce, GTK, ctr) @ i"

lemma supplicant_can_send_m4 [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK authThreadID PTK ANonce SNonce GTK #i.
     SupplicantSendsM4(suppThreadID, suppID, PMK, authThreadID, PTK, GTK,
                       ANonce, SNonce) @ i"

lemma can_install_key [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID authThreadID authID PMK ptkID PTK ptkNonce GTK 
     ANonce SNonce ctr1 #i #j.
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID, PTK,
                            ANonce, SNonce, ctr1) @ i & 
     SupplicantInstalledPTK(suppThreadID, suppID, PMK, ptkID, PTK, ptkNonce,
                            GTK, ANonce, SNonce) @ j"

lemma can_perform_handshakes_in_parallel [heuristic=S, 
                                          hide_unwanted_lemmas]: exists-trace
    "Ex authID authThreadID1 authThreadID2 suppID1 suppID2
     suppThreadID1 suppThreadID2 PMK1 PMK2 ptkID1 ptkID2 ptkNonce1 ptkNonce2
     PTK1 PTK2 GTK ANonce1 ANonce2 SNonce1 SNonce2 #i #j #k #l.
     Associate(authID, authThreadID1, suppID1, suppThreadID1, PMK1) @ i &
     Associate(authID, authThreadID2, suppID2, suppThreadID2, PMK2) @ j &
     i < j & k < l &
     SupplicantInstalledPTK(suppThreadID2, suppID2, PMK2, ptkID2, PTK2,
                            ptkNonce2, GTK, ANonce2, SNonce2) @ k &
     SupplicantInstalledPTK(suppThreadID1, suppID1, PMK1, ptkID1, PTK1,
                            ptkNonce1, GTK, ANonce1, SNonce1) @ l"

lemma can_rekey [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex authThreadID authID PMK suppThreadID1 suppThreadID2 PTK1 PTK2 
     ANonce1 ANonce2 SNonce1 SNonce2 ctr1 ctr2 #i #j.
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID1, PTK1, 
                            ANonce1, SNonce1, ctr1) @ i & 
     AuthenticatorInstalled(authThreadID, authID, PMK, suppThreadID2, PTK2, 
                            ANonce2, SNonce2, ctr2) @ j & 
     (not #i = #j)"

lemma can_receive_group_payloads [heuristic=S, 
                                  hide_unwanted_lemmas]: exists-trace
    "Ex keyID suppThreadID PMK groupKey nonce1 nonce2 #i #j.
     ReceiveGTKEncryptedPayload(keyID, suppThreadID, PMK, groupKey, nonce1) @ i &
     ReceiveGTKEncryptedPayload(keyID, suppThreadID, PMK, groupKey, nonce2) @ j &
     i < j"

lemma authenticator_can_install_new_gtk [heuristic=S, 
                                         hide_unwanted_lemmas]: exists-trace
    "Ex authID shareGTKData authThreadID1 suppID1 suppThreadID1 PMK1
     authThreadID2 suppID2 suppThreadID2 PMK2 #i #j #k.
     Associate(authID, authThreadID1, suppID1, suppThreadID1, PMK1) @ i &
     Associate(authID, authThreadID2, suppID2, suppThreadID2, PMK2) @ j &
     AuthenticatorInstalledGTK(authID, shareGTKData) @ k &
     i < k & j < k"

lemma krack_attack_ptk [heuristic=S, hide_unwanted_lemmas]: exists-trace
    "Ex suppThreadID suppID PMK ptkID PTK ptkNonce GTK ANonce SNonce #i #j.
     SupplicantInstalledPTK(suppThreadID, suppID, PMK, ptkID, PTK, ptkNonce,
                            GTK, ANonce, SNonce) @ i &
     K(PTK) @ j"
     /*NonceReuse(PTK, kPTKNonceStartNumber) @ j & i < j"*/

// END Plausibility Checks

end
