#!/usr/bin/env bash
# Run this script from the parent directory (i.e., the 'wpa2_model' directory)
cp automatic_proofs/authenticator_preliminary_ptk_is_secret.spthy automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy
cp automatic_proofs/authenticator_ptk_is_secret.spthy automatic_proofs/authenticator_ptk_is_ku_secret.spthy
cp automatic_proofs/supplicant_preliminary_ptk_is_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy
cp automatic_proofs/supplicant_ptk_is_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy

sed -i -e 's/#vk /#k /g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
sed -i -e 's/#vk /#k.1 /g' automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy
sed -i -e 's/#vk.2 /#vk.1 /g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
sed -i -e 's/#vk.3 /#vk.2 /g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy

sed -i -e 's/ptk_is_ku_secret/XYZ/g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
sed -i -e 's/ptk_is_secret/ptk_is_ku_secret/g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
sed -i -e 's/XYZ/ptk_is_secret/g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy

sed -i -e 's/#k. !KU( K/#k. X( K/g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy
sed -i -e 's/#k. !KU( P/#k. X( P/g' automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
sed -i -e 's/#k. K( K/#k. !KU( K/g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy
sed -i -e 's/#k. K( P/#k. !KU( P/g' automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
sed -i -e 's/#k. X( K/#k. K( K/g' automatic_proofs/authenticator_preliminary_ptk_is_ku_secret.spthy automatic_proofs/supplicant_preliminary_ptk_is_ku_secret.spthy
sed -i -e 's/#k. X( P/#k. K( P/g' automatic_proofs/authenticator_ptk_is_ku_secret.spthy automatic_proofs/supplicant_ptk_is_ku_secret.spthy
