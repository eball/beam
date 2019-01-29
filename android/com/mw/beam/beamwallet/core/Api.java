// Copyright 2018 The Beam Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.mw.beam.beamwallet.core;

import  com.mw.beam.beamwallet.core.entities.Wallet;

public class Api
{
	public native boolean isWalletInitialized(String path);	
	public native Wallet createWallet(String nodeAddr, String path, String pass, String phrases);
	public native Wallet openWallet(String nodeAddr, String path, String pass);
	public native String[] createMnemonic();
    public native boolean checkReceiverAddress(String address);

	static 
	{
		System.loadLibrary("wallet-jni");
	}
}
