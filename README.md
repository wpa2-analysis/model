# A Formal Analysis of IEEE 802.11's WPA2

This repository contains a formal model of IEEE 802.11's WPA2 protocol together with proofs of several security properties. The model is created for the theorem prover [Tamarin](https://tamarin-prover.github.io/) and is discussed in a USENIX submission that is currently under review.

## Prerequisites

To produce our formal model we used the [Tamarin prover](https://tamarin-prover.github.io/) version 1.5.1 (Git revision: ab0c43dfab9a22a740c4cb6d7fc5cd719db10d2f, branch: develop). Installation instructions for Tamarin can be found [here](https://tamarin-prover.github.io/manual/book/002_installation.html). You need Tamarin to inspect the model, run proofs, and verify existing proofs. Note that Tamarin runs on Linux and Mac, but not on Windows. If you plan to use or edit the model, you also need the [GNU M4 macro preprocessor](https://www.gnu.org/software/m4/).

## Files of the Formal Model

The main file, containing the formal model of WPA2 together with all lemmas, is [model/wpa2_four_way_handshake.m4](model/wpa2_four_way_handshake.m4). This file needs to be preprocessed with the [GNU M4 macro preprocessor](https://www.gnu.org/software/m4/) to turn it into valid input for Tamarin (see below for details). 

If you don't want to use M4 and are only interested in the resulting Tamarin files, then the following two files will be enough for you (note that although these files can be read by Tamarin, the original M4 file is more readable):

* [model/wpa2_four_way_handshake_patched.spthy](model/wpa2_four_way_handshake_patched.spthy) - A formal model of WPA2 including patches/countermeasures aimed at avoiding key-reinstallation attacks.

* [model/wpa2_four_way_handshake_unpatched.spthy](model/wpa2_four_way_handshake_unpatched.spthy) - A formal model of WPA2 without the patches/countermeasures.

The first file is obtained from [wpa2_four_way_handshake.m4](model/wpa2_four_way_handshake.m4) by runnning the following command:

`m4 wpa2_four_way_handshake.m4 > wpa2_four_way_handshake_patched.spthy`

The second file is obtained from [wpa2_four_way_handshake.m4](model/wpa2_four_way_handshake.m4) by setting the M4 macro `INCLUDE_PATCHES` to false in the header (line 6) of [wpa2_four_way_handshake.m4](model/wpa2_four_way_handshake.m4) and then running:

`m4 wpa2_four_way_handshake.m4 > wpa2_four_way_handshake_unpatched.spthy`

Note that the formal model of the WPA2 encryption layer (discussed in our paper) is specified in the file [model/encryption_layer.m4i](model/encryption_layer.m4i), which is included by [model/wpa2_four_way_handshake.m4](model/wpa2_four_way_handshake.m4).

## Overview of the Model

The model file [wpa2_four_way_handshake.m4](model/wpa2_four_way_handshake.m4) consists of the following parts (in the same order as presented here):

* Several definitions of constants/macros as well as definitions of function symbols and an equation defining nonce-based encryption/decryption.

* Restrictions (starting at line 34) that handle (1) Checks for equality and inequality (used, e.g., for modeling the verification of message integrity codes), (2) a FIFO restriction for the message queue, which is part of the encryption layer, (3) the replay-counter mechanisms (on the receiver side) and (4) restrictions for modeling memory allocation. **Note that (in contrast to the illustrative example in Section 2 of our paper), replay counters on the sender side are not modeled/restricted with restrictions.**

* Setup/Creation of supplicants and authenticators as well as a rule for associating authenticator threads with supplicant threads (starting at line 122).

* The encryption layer (mostly defined in [model/encryption_layer.m4i](model/encryption_layer.m4i)) as well as rules for modeling nonce reuse and key compromise (starting at line 186).

* The authenticator state machine for the four-way handshake (starting at line 279) followed by the supplicant state machine for the four-way handshake (starting at line 467)

* The group-key handshake state machines for the supplicant (starting at line 670) and for the authenticator (starting at line 715)

* The state machines for the communication related to WNM sleep mode, starting with the part for the authenticator (from line 875), followed by the part for the supplicant (from line 939).

The rest of the file then contains all lemmas, followed by existential statements that serve as plausibility checks. The final lemma (*krack_attack_ptk* at line 1785) is an existential statement for the KRACK attack on the four-way handshake (see below).

## Proof Files

The proofs of all lemmas (in the patched model) are contained in the folder [proofs](proofs). Each file in the folder is named after the lemma it proves, with the suffix '.spthy'. For example, the proof of lemma 'authenticator_ptk_is_secret' is in the file [proofs/authenticator_ptk_is_secret.spthy](proofs/authenticator_ptk_is_secret.spthy). 

To validate a proof and to inspect it in the Tamarin GUI, just start Tamarin in *interactive mode* and then open the corresponding file (we recommend to start interactive mode in a folder different from [proofs](proofs) because otherwise Tamarin runs on all the files in this folder, which could take very long):

`tamarin-prover --interactive [start_folder_for_interactive_mode]`

Above, replace `[start_folder_for_interactive_mode]` by the folder from which you want to run Tamarin.

## KRACK Attack

The folder [traces](traces) contains a Tamarin file with an attack trace for a [KRACK attack](https://www.krackattacks.com/) on the WPA2 four-way handshake (in file [krack_attack_ptk.spthy](traces/krack_attack_ptk.spthy)). The attack is on the unpatched model, i.e., the version of the model that does not contain the countermeasures aimed at preventing key-reinstallation attacks. A corresponding picture (produced by Tamarin) showing the attack trace is also contained in the folder: [krack_attack_ptk.png](traces/krack_attack_ptk.png).

In the picture of the trace, the authenticator is colored purple whereas the supplicant is colored blue. Notice how the rule *Supp_Install_Key_Snd_M4* occurs twice, leading to the reinstallation of the PTK `KDF(<~PMK, ~ANonce, ~SNonce>)`. This resets the corresponding nonce. Since the supplicant sends two different messages (yellow rule *sendPTKEncryptedPayloadSupp*) with the same key and the same nonce, this allows the attacker to learn the PTK with the (red) rule *KeyRevealFromNonceReuse*.

## Kr00k Vulnerability

The [Kr00k vulnerability](https://www.eset.com/int/kr00k/), reported a few days after submission of our paper, does not indicate a vulnerability in the IEEE standard that we analyze; rather, it is related to a flaw in the implementations of some Wi-Fi chips. In particular, a Kr00k attack exploits that---counter to the expected behavior---some (unpatched) Wi-Fi chips still encrypt and transmit messages after a client has been disassociated. The discovery of the Kr00k vulnerability therefore doesn't invalidate any of the results of our analysis. Note that one can observe that Kr00k also has no consequences for the IEEE documents.

## USENIX Artifact Submission

For the USENIX artifact evaluation, we will additionally produce a virtual machine containing the files contained in this repository as well as a pre-installed Tamarin and automatic reproduction scripts in the next weeks.
