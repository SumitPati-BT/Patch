/**
 * Description : Utility methods to be invoked from handler class of
 *               transaction trigger
 * [02.Feb.2020] Plative - Created
 */
public class TransactionTriggerHelperNew{
	public static Id checkingAccountId;
	public static Id dimension1Id;
	public static List<General_Ledger_Account_Mapping__mdt> lstGLAccountMapping;
	public static Map<String, Id> mapDim3NameToId;
	/*
	 * Description: Create Journal Entries on Transaction creation
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static void processTransactionsByType(List<bt_stripe__Transaction__c> lstNewTrx, Map<Id, bt_stripe__Transaction__c> mapOldTxn){

		List<bt_stripe__Transaction__c> lstCharges = new List<bt_stripe__Transaction__c>();
		List<bt_stripe__Transaction__c> lstPayouts = new List<bt_stripe__Transaction__c>();
		List<bt_stripe__Transaction__c> lstRefunds = new List<bt_stripe__Transaction__c>();

		Id chargeRTId = Schema.SObjectType.bt_stripe__Transaction__c.getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId();
		Id payoutRTId = Schema.SObjectType.bt_stripe__Transaction__c.getRecordTypeInfosByDeveloperName().get('Payout').getRecordTypeId();

		Set<String> setDescription = new Set<String>();
		Set<Id> setPayoutIds = new Set<Id>();

		Datetime stripeTransactionStartDate = DateTime.parse(Label.Stripe_Transaction_Start_Date);

		for (bt_stripe__Transaction__c txn : lstNewTrx){
			System.debug('chargeRTId: ' + chargeRTId + ' RecordTypeId: ' + txn.RecordTypeId + ' txn.bt_stripe__Transaction_Type__c: ' + txn.bt_stripe__Transaction_Type__c);
			if (txn.bt_stripe__Processed_Date__c != null && txn.bt_stripe__Processed_Date__c < stripeTransactionStartDate){
				continue;
			}
			if (String.isNotBlank(txn.bt_stripe__Description__c)){
				System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ isNotBlank txn ' + txn);
				System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ isNotBlank txn.bt_stripe__Description__c : ' + txn.bt_stripe__Description__c);
				setDescription.add(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 
																					'Patch Membership' : txn.bt_stripe__Description__c);
			} else{
				// setDescription.add('Check');
				System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ txn ' + txn);
				System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ txn.bt_stripe__Description__c : ' + txn.bt_stripe__Description__c);
				txn.addError('Please add a description');
				continue;
			}

			//Charges
			if (txn.RecordTypeId == chargeRTId && ((mapOldTxn == null) || (mapOldTxn.get(txn.Id).bt_stripe__Transaction_Status__c != 'Completed')) && txn.bt_stripe__Transaction_Type__c == 'Normal' && txn.bt_stripe__Transaction_Status__c == 'Completed'){
				lstCharges.add(txn);
				continue;
			}

			//Refunds
			if (txn.RecordTypeId == chargeRTId && ((mapOldTxn == null) || (mapOldTxn.get(txn.Id).bt_stripe__Transaction_Status__c != 'Completed')) && txn.bt_stripe__Transaction_Type__c == 'Refund' && txn.bt_stripe__Transaction_Status__c == 'Completed'){
				lstRefunds.add(txn);
				continue;
			}
			//Payouts
			if ((txn.RecordTypeId == payoutRTId) && (mapOldTxn != null) && txn.bt_stripe__Transaction_Status__c == 'Completed' && (mapOldTxn.get(txn.Id).bt_stripe__Transaction_Status__c != 'Completed')){
				setPayoutIds.add(txn.Id);
				lstPayouts.add(txn);
			}
		}

		if (dimension1Id == null)
			dimension1Id = getDimension1Record('Corporate');
		System.debug('@@@@@@@@@@@@@@@@dimension1Id : ' + dimension1Id);
		if (mapDim3NameToId == null)
			mapDim3NameToId = getDimension3RecordsMap(setDescription);
		System.debug('@@@@@@@@@@@@@@@@mapDim3NameToId : ' + mapDim3NameToId);
		if (checkingAccountId == null)
			checkingAccountId = getCheckingBankAccount();
		System.debug('@@@@@@@@@@@@@@@@checkingAccountId : ' + checkingAccountId);
		List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();

		if (!lstCharges.isEmpty())
			lstWrapper.addAll(createEntriesForCharge(lstCharges, dimension1Id, mapDim3NameToId));
		System.debug('lstCharges : ' + lstCharges);
		System.debug('lstWrapper lstCharges : ' + lstWrapper);
		if (!lstPayouts.isEmpty())
			lstWrapper.addAll(createEntriesForPayout(lstPayouts, setPayoutIds));
		System.debug('lstPayouts : ' + lstPayouts);
		System.debug('lstWrapper lstPayouts : ' + lstWrapper);
		if (!lstRefunds.isEmpty())
			lstWrapper.addAll(createEntriesForRefund(lstRefunds, dimension1Id, mapDim3NameToId));
		System.debug('lstRefunds : ' + lstRefunds);
		System.debug('lstWrapper lstRefunds : ' + lstWrapper);
		if (!lstWrapper.isEmpty())
			insertJournalRecords(lstWrapper);
	}

	/*
	 * Description: Parses wrapper and inserts Journal Entry and lines
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static void insertJournalRecords(List<JournalEntryWrapper> lstWrapper){
		List<c2g__codaJournal__c> lstJE = new List<c2g__codaJournal__c>();
		for (JournalEntryWrapper wrapper : lstWrapper){
			lstJE.add(wrapper.je);
		}
		insert lstJE;

		List<c2g__codaJournalLineItem__c> lstLinesToInsert = new List<c2g__codaJournalLineItem__c>();
		for (JournalEntryWrapper wrapper : lstWrapper){
			for (c2g__codaJournalLineItem__c line : wrapper.lstLines){
				line.c2g__Journal__c = wrapper.je.Id;
				lstLinesToInsert.add(line);
			}
		}
		System.debug('lstLinesToInsert: ' + lstLinesToInsert);
		AccessControlWithoutSharing.dmlInsert(lstLinesToInsert);
		System.debug('lstLinesToInsert: after ' + lstLinesToInsert);
		// insert lstLinesToInsert;
	}

	/*
	 * Description: Create Journal Entries for Charge type Transaction
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createEntriesForCharge(List<bt_stripe__Transaction__c> lstNewTrx, Id dimension1Id, Map<String, Id> mapDim3NameToId){
		List<c2g__codaJournal__c> lstJE = new List<c2g__codaJournal__c>();
		List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();

		for (bt_stripe__Transaction__c txn : lstNewTrx){
			lstWrapper.addAll(createEntriesAndLinesForCharge(txn, dimension1Id, mapDim3NameToId));
		}
		return lstWrapper;
	}

	/*
	 * Description: Create Journal Entry and Lines
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createEntriesAndLinesForCharge(bt_stripe__Transaction__c txn, Id dimension1Id, Map<String, Id> mapDim3NameToId){
		c2g__codaJournal__c je = new c2g__codaJournal__c();
		if (txn.bt_stripe__Processed_Date__c != null){
			je.c2g__JournalDate__c = txn.bt_stripe__Processed_Date__c.date();
		}
		String description = txn.Patch_ID__c;
		if (String.isNotBlank(txn.Patch_Shared__c)){
			description += ',' + txn.Patch_Shared__c.stripHtmlTags();
		}
		je.Additional_Description__c = description;
		je.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Charges + ' ' + txn.bt_stripe__Transaction_Id__c;
		JournalEntryWrapper wrapper = new JournalEntryWrapper();
		wrapper.je = je;
		List<c2g__codaJournalLineItem__c> lstLines = new List<c2g__codaJournalLineItem__c>();

		String productType = txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 
																			  'Patch Membership' : 'Platform';

		//Create line for AR
		c2g__codaJournalLineItem__c arLine = new c2g__codaJournalLineItem__c();
		arLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		arLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
		arLine.c2g__LineType__c = 'General Ledger Account';
		arLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	arLine.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	arLine.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	arLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		arLine.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Account Receivable');
		arLine.c2g__DebitCredit__c = 'Debit';
		arLine.c2g__Value__c = txn.bt_stripe__Amount__c;
		lstLines.add(arLine);

		//Create line for Deferred Revenue
		c2g__codaJournalLineItem__c defRev = new c2g__codaJournalLineItem__c();
		defRev.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		defRev.c2g__AccountAnalysis__c = txn.bt_stripe__Related_Account__c;
		defRev.c2g__LineType__c = 'General Ledger Account';
		defRev.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	defRev.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	defRev.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	defRev.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		defRev.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Deferred Revenue');
		defRev.c2g__DebitCredit__c = 'Credit';
		defRev.c2g__Value__c = 0-txn.bt_stripe__Amount__c;
		lstLines.add(defRev);

		//Create line for AP
		if (txn.bt_stripe__Stripe_Fee_Total__c != null && txn.bt_stripe__Stripe_Fee_Total__c > 0){
			c2g__codaJournalLineItem__c apLine = new c2g__codaJournalLineItem__c();
			apLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			apLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			apLine.c2g__LineType__c = 'General Ledger Account';
			apLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
			                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
			// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
			// 	apLine.c2g__Dimension3__c = 'Patch Membership';
			// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
			// 	apLine.c2g__Dimension3__c = 'Patch Featured Business';
			// } else{
			// 	apLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
			// }
			apLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Accounts Payable');
			apLine.c2g__DebitCredit__c = 'Credit';
			apLine.c2g__Value__c = 0-txn.bt_stripe__Stripe_Fee_Total__c;
			lstLines.add(apLine);
		}

		//Create line for Billing
		if (txn.bt_stripe__Stripe_Fee_Total__c != null && txn.bt_stripe__Stripe_Fee_Total__c > 0){
			c2g__codaJournalLineItem__c billingLine = new c2g__codaJournalLineItem__c();
			billingLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			billingLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			billingLine.c2g__LineType__c = 'General Ledger Account';
			billingLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 'Patch Membership' : txn.bt_stripe__Description__c);
			// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
			// 	billingLine.c2g__Dimension3__c = 'Patch Membership';
			// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
			// 	billingLine.c2g__Dimension3__c = 'Patch Featured Business';
			// } else{
			// 	billingLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
			// }
			billingLine.c2g__Dimension1__c = dimension1Id;
			billingLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Profit and Loss');
			billingLine.c2g__DebitCredit__c = 'Debit';
			billingLine.c2g__Value__c = txn.bt_stripe__Stripe_Fee_Total__c;
			lstLines.add(billingLine);
		}

		wrapper.lstLines = lstLines;

		return new List<JournalEntryWrapper>{wrapper};
	}

	/*
	 * Description: Create Journal Entries for Refund type Transaction
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createEntriesForRefund(List<bt_stripe__Transaction__c> lstNewTrx, Id dimension1Id, Map<String, Id> mapDim3NameToId){
		List<c2g__codaJournal__c> lstJE = new List<c2g__codaJournal__c>();
		List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();
		Set<String> setTxnIds = new Set<String>();

		for (bt_stripe__Transaction__c txn : lstNewTrx){
			lstWrapper.addAll(createEntriesAndLinesForRefund(txn, dimension1Id, mapDim3NameToId));
			setTxnIds.add(System.label.Journal_Description_Prefix_for_Rev_Rec + ' ' + txn.bt_stripe__Parent_Transaction__c);
		}
		System.debug('@@@@@@@@@@@ lstWrapper : ' + lstWrapper);
		System.debug('@@@@@@@@@@@ setTxnIds : ' + setTxnIds);
		return lstWrapper;
	}

	/*
	 * Description: Create Journal Entry and Lines for Refunds
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createEntriesAndLinesForRefund(bt_stripe__Transaction__c txn, Id dimension1Id, Map<String, Id> mapDim3NameToId){
		c2g__codaJournal__c je = new c2g__codaJournal__c();
		if (txn.bt_stripe__Processed_Date__c != null){
			je.c2g__JournalDate__c = txn.bt_stripe__Processed_Date__c.date();
		}
		String description = txn.Patch_ID__c;
		if (String.isNotBlank(txn.Patch_Shared__c)){
			description += ',' + txn.Patch_Shared__c.stripHtmlTags();
		}
		je.Additional_Description__c = description;
		je.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Charges + ' ' + txn.bt_stripe__Transaction_Id__c;
		je.c2g__Reference__c = txn.bt_stripe__Parent_Transaction_Id__c;
		JournalEntryWrapper wrapper = new JournalEntryWrapper();
		wrapper.je = je;
		List<c2g__codaJournalLineItem__c> lstLines = new List<c2g__codaJournalLineItem__c>();

		String productType = txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 
																			  'Patch Membership' : 'Platform';
		System.debug('@@@@@@@@@@@@@  ' + txn);
		System.debug('@@@@@@@@@@@@@  ' + txn.bt_stripe__Related_Account__c);
		//Create line for pnl
		c2g__codaJournalLineItem__c pnlLine = new c2g__codaJournalLineItem__c();
		pnlLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		pnlLine.c2g__AccountAnalysis__c = txn.bt_stripe__Related_Account__c;
		pnlLine.c2g__LineType__c = 'General Ledger Account';
		pnlLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                  'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	pnlLine.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	pnlLine.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	pnlLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		pnlLine.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Profit and Loss');
		pnlLine.c2g__DebitCredit__c = 'Debit';
		pnlLine.c2g__Value__c = Math.abs(txn.bt_stripe__Amount__c.setScale(2));  //refund amount
		lstLines.add(pnlLine);

		//Create line for Account Receivable
		c2g__codaJournalLineItem__c arLine = new c2g__codaJournalLineItem__c();
		arLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		arLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
		arLine.c2g__LineType__c = 'General Ledger Account';
		System.debug('txn.bt_stripe__Description__c.containsIgnoreCase(\'INVOICE\') : ' + txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE'));
		arLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	arLine.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	arLine.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	arLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		arLine.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Account Receivable');
		arLine.c2g__DebitCredit__c = 'Credit';
		arLine.c2g__Value__c = 0-Math.abs(txn.bt_stripe__Amount__c.setScale(2));
		lstLines.add(arLine);

		//Create line for AP
		if (txn.bt_stripe__Stripe_Fee_Total__c != null && txn.bt_stripe__Stripe_Fee_Total__c > 0){
			c2g__codaJournalLineItem__c apLine = new c2g__codaJournalLineItem__c();
			apLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			apLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			apLine.c2g__LineType__c = 'General Ledger Account';
			apLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
			                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
			// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
			// 	apLine.c2g__Dimension3__c = 'Patch Membership';
			// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
			// 	apLine.c2g__Dimension3__c = 'Patch Featured Business';
			// } else{
			// 	apLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
			// }
			apLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Accounts Payable');
			apLine.c2g__DebitCredit__c = 'Credit';
			apLine.c2g__Value__c = 0-txn.bt_stripe__Stripe_Fee_Total__c;
			lstLines.add(apLine);
		}

		//Create line for AP
		if (txn.bt_stripe__Stripe_Fee_Total__c != null && txn.bt_stripe__Stripe_Fee_Total__c < 0){
			c2g__codaJournalLineItem__c apLine = new c2g__codaJournalLineItem__c();
			apLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			apLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			apLine.c2g__LineType__c = 'General Ledger Account';
			apLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
			                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
			// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
			// 	apLine.c2g__Dimension3__c = 'Patch Membership';
			// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
			// 	apLine.c2g__Dimension3__c = 'Patch Featured Business';
			// } else{
			// 	apLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
			// }
			apLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Accounts Payable');
			apLine.c2g__DebitCredit__c = 'Debit';
			apLine.c2g__Value__c = 0-txn.bt_stripe__Stripe_Fee_Total__c;
			lstLines.add(apLine);
		}

		//Create line for Billing
		if (txn.bt_stripe__Stripe_Fee_Total__c != null && txn.bt_stripe__Stripe_Fee_Total__c > 0){
			c2g__codaJournalLineItem__c billingLine = new c2g__codaJournalLineItem__c();
			billingLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			billingLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			billingLine.c2g__LineType__c = 'General Ledger Account';
			billingLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
			                                                                                                      'Patch Membership' : txn.bt_stripe__Description__c);
			// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
			// 	billingLine.c2g__Dimension3__c = 'Patch Membership';
			// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
			// 	billingLine.c2g__Dimension3__c = 'Patch Featured Business';
			// } else{
			// 	billingLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
			// }
			billingLine.c2g__Dimension1__c = dimension1Id;
			billingLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Profit and Loss');
			billingLine.c2g__DebitCredit__c = 'Debit';
			billingLine.c2g__Value__c = txn.bt_stripe__Stripe_Fee_Total__c;
			lstLines.add(billingLine);
		}

		//Create line for Billing
		if (txn.bt_stripe__Stripe_Fee_Total__c != null && txn.bt_stripe__Stripe_Fee_Total__c < 0){
			c2g__codaJournalLineItem__c billingLine = new c2g__codaJournalLineItem__c();
			billingLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			billingLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			billingLine.c2g__LineType__c = 'General Ledger Account';
			billingLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
			                                                                                                      'Patch Membership' : txn.bt_stripe__Description__c);
			// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
			// 	billingLine.c2g__Dimension3__c = 'Patch Membership';
			// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
			// 	billingLine.c2g__Dimension3__c = 'Patch Featured Business';
			// } else{
			// 	billingLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
			// }
			billingLine.c2g__Dimension1__c = dimension1Id;
			billingLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Profit and Loss');
			billingLine.c2g__DebitCredit__c = 'Credit';
			billingLine.c2g__Value__c = txn.bt_stripe__Stripe_Fee_Total__c;
			lstLines.add(billingLine);
		}

		wrapper.lstLines = lstLines;

		return new List<JournalEntryWrapper>{wrapper};
	}

	/*
	 * Description: Create Journal Entries for Payout type Transaction
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createEntriesForPayout(List<bt_stripe__Transaction__c> lstNewTrx, Set<Id> setPayoutIds){
		List<c2g__codaJournal__c> lstJE = new List<c2g__codaJournal__c>();
		List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();

		//Calculate sum of all transaction amounts for payouts

		List<AggregateResult> lstResult1 = [SELECT bt_stripe__Payout__c, SUM(bt_stripe__Amount__c)AMOUNT, SUM(bt_stripe__Stripe_Fee_Total__c)FEE
		                                    FROM bt_stripe__Transaction__c
		                                    WHERE bt_stripe__Payout__c IN :setPayoutIds AND bt_stripe__Description__c LIKE '%Invoice%'
		                                    GROUP BY bt_stripe__Payout__c];

		List<AggregateResult> lstResult2 = [SELECT bt_stripe__Payout__c, SUM(bt_stripe__Amount__c)AMOUNT, SUM(bt_stripe__Stripe_Fee_Total__c)FEE
		                                    FROM bt_stripe__Transaction__c
		                                    WHERE bt_stripe__Payout__c IN :setPayoutIds AND ( NOT bt_stripe__Description__c LIKE '%Invoice%')
		                                    GROUP BY bt_stripe__Payout__c];

		for (bt_stripe__Transaction__c txn : lstNewTrx){
			Decimal sumAmountInvoice = 0;
			Decimal sumAmount = 0;
			Decimal sumGatewayFee = 0;
			for (AggregateResult aggr : lstResult1){
				if ((Id)aggr.get('bt_stripe__Payout__c') == txn.Id){
					sumAmountInvoice = (Decimal)aggr.get('AMOUNT');
					sumGatewayFee = (Decimal)aggr.get('FEE');
				}
			}
			for (AggregateResult aggr : lstResult2){
				if ((Id)aggr.get('bt_stripe__Payout__c') == txn.Id){
					sumAmount = (Decimal)aggr.get('AMOUNT');
					sumGatewayFee += (Decimal)aggr.get('FEE');
				}
			}
			lstWrapper.addAll(createEntriesAndLinesForPayout(txn, sumAmountInvoice, sumAmount, sumGatewayFee));
		}
		return lstWrapper;
	}

	/*
	 * Description: Create Journal Entry and Lines for Payout type transactions
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createEntriesAndLinesForPayout(bt_stripe__Transaction__c txn, Decimal sumAmountInvoice, Decimal sumAmount, Decimal sumGatewayFee){
		c2g__codaJournal__c je = new c2g__codaJournal__c();
		if (txn.bt_stripe__Payout_Processed_Date__c != null){
			je.c2g__JournalDate__c = txn.bt_stripe__Payout_Processed_Date__c.date();
		}
		je.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Payout + ' - ' + txn.bt_stripe__Transaction_Id__c;
		JournalEntryWrapper wrapper = new JournalEntryWrapper();
		wrapper.je = je;
		List<c2g__codaJournalLineItem__c> lstLines = new List<c2g__codaJournalLineItem__c>();

		//Create line for AR
		if (sumAmountInvoice > 0){
			c2g__codaJournalLineItem__c arLine = new c2g__codaJournalLineItem__c();
			arLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			arLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			arLine.c2g__LineType__c = 'General Ledger Account';
			arLine.c2g__GeneralLedgerAccount__c = getGLAccount('Patch Membership', 'Account Receivable');
			arLine.c2g__DebitCredit__c = 'Credit';
			arLine.c2g__Value__c = 0-sumAmountInvoice;
			lstLines.add(arLine);
		}

		if (sumAmount > 0){
			c2g__codaJournalLineItem__c arLine = new c2g__codaJournalLineItem__c();
			arLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			arLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			arLine.c2g__LineType__c = 'General Ledger Account';
			arLine.c2g__GeneralLedgerAccount__c = getGLAccount('Platform', 'Account Receivable');
			arLine.c2g__DebitCredit__c = 'Credit';
			arLine.c2g__Value__c = 0-sumAmount;
			lstLines.add(arLine);
		}

		//Create line for Checking Account
		c2g__codaJournalLineItem__c checkingLine2 = new c2g__codaJournalLineItem__c();
		checkingLine2.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		checkingLine2.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
		checkingLine2.c2g__LineType__c = 'Bank Account';
		checkingLine2.c2g__BankAccount__c = checkingAccountId;
		checkingLine2.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Balance Sheet');
		checkingLine2.c2g__DebitCredit__c = 'Debit';
		checkingLine2.c2g__Value__c = (sumAmountInvoice + sumAmount)-sumGatewayFee;
		lstLines.add(checkingLine2);

		//Create line for AP
		if (sumGatewayFee != null && sumGatewayFee > 0){

			c2g__codaJournalLineItem__c apLine = new c2g__codaJournalLineItem__c();
			apLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
			apLine.c2g__AccountAnalysis__c = Id.valueOf(System.label.Stripe_Account_Id);
			apLine.c2g__LineType__c = 'General Ledger Account';
			apLine.c2g__GeneralLedgerAccount__c = getGLAccount('', 'Accounts Payable');
			apLine.c2g__DebitCredit__c = 'Debit';
			apLine.c2g__Value__c = sumGatewayFee;
			lstLines.add(apLine);
		}

		wrapper.lstLines = lstLines;

		return new List<JournalEntryWrapper>{wrapper};
	}

	/*
	 * Description: Create Journal Entries for Revenue Recognition
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createRRJEForCharge(bt_stripe__Transaction__c txn, Map<String, Id> mapDim3NameToId, Date serviceStartDate, Date serviceEndDate){
		List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();
		serviceStartDate = txn.Promoted_Start_Date__c > serviceStartDate ? txn.Promoted_Start_Date__c : serviceStartDate;
		Integer noOfMonths = serviceStartDate.monthsBetween(serviceEndDate);
		Integer totalServiceDays = txn.Promoted_Start_Date__c.daysBetween(txn.Promoted_End_Date__c)+1;
		Decimal dailyRate = txn.bt_stripe__Amount__c / totalServiceDays;
		Integer serviceDays = 0;
		String description = txn.Patch_ID__c;
		if (String.isNotBlank(txn.Patch_Shared__c)){
			description += ',' + txn.Patch_Shared__c.stripHtmlTags();
		}

		//If service day less than a month, create one Revenue Recognition JE
		if (noOfMonths == 0){
			Integer numberOfDays = Date.daysInMonth(serviceStartDate.year(), serviceStartDate.month());
			Date lastDayOfMonth = Date.newInstance(serviceStartDate.year(), serviceStartDate.month(), numberOfDays);
			serviceDays = serviceEndDate.day()-serviceStartDate.day();
			serviceDays++;
			c2g__codaJournal__c revenueRecJE = new c2g__codaJournal__c();
			revenueRecJE.c2g__JournalDate__c = lastDayOfMonth;
			revenueRecJE.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Rev_Rec + ' ' + txn.bt_stripe__Transaction_Id__c;
			revenueRecJE.c2g__Reference__c = txn.bt_stripe__Parent_Transaction__c;
			revenueRecJE.Additional_Description__c = description;
			JournalEntryWrapper wrapper = new JournalEntryWrapper();
			wrapper.je = revenueRecJE;
			if (dailyRate * serviceDays == 0)
				return lstWrapper;
			wrapper.lstLines.addAll(createRevRecJELinesForCharge(txn, dailyRate * serviceDays, mapDim3NameToId));
			lstWrapper.add(wrapper);
			return lstWrapper;
		}

		for (integer i = 0; i <= noOfMonths; i++){
			serviceDays = 0;
			Integer numberOfDays = Date.daysInMonth(serviceStartDate.year(), serviceStartDate.month());
			Date lastDayOfMonth = Date.newInstance(serviceStartDate.year(), serviceStartDate.month(), numberOfDays);
			if (lastDayOfMonth > serviceEndDate){
				serviceDays = serviceEndDate.day()-serviceStartDate.day();
			} else{
				serviceDays = lastDayOfMonth.day()-serviceStartDate.day();
			}
			c2g__codaJournal__c revenueRecJE = new c2g__codaJournal__c();
			revenueRecJE.c2g__JournalDate__c = lastDayOfMonth;
			revenueRecJE.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Rev_Rec + ' ' + txn.bt_stripe__Transaction_Id__c;
			revenueRecJE.c2g__Reference__c = txn.bt_stripe__Parent_Transaction__c;
			JournalEntryWrapper wrapper = new JournalEntryWrapper();
			wrapper.je = revenueRecJE;
			wrapper.lstLines.addAll(createRevRecJELinesForCharge(txn, dailyRate * serviceDays, mapDim3NameToId));
			lstWrapper.add(wrapper);
			serviceStartDate = lastDayOfMonth.addDays(1);
		}
		return lstWrapper;
	}

	/*
	 * Description: Create Revenue Recognition journal entries for
	 * Created    : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static List<JournalEntryWrapper> createRRJEForChargeWithRefund(bt_stripe__Transaction__c txn, Map<String, Id> mapDim3NameToId, Date serviceStartDate){
		List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();
		serviceStartDate = txn.Promoted_Start_Date__c > serviceStartDate ? txn.Promoted_Start_Date__c : serviceStartDate;
		Integer totalServiceDays = txn.Promoted_Start_Date__c.daysBetween(txn.Promoted_End_Date__c)+1;
		Decimal dailyRate = txn.bt_stripe__Amount__c / totalServiceDays;
		Integer serviceDays = 0;
		String description = txn.Patch_ID__c;
		if (String.isNotBlank(txn.Patch_Shared__c)){
			description += ',' + txn.Patch_Shared__c.stripHtmlTags();
		}
		Integer numberOfDays = Date.daysInMonth(serviceStartDate.year(), serviceStartDate.month());
		Date lastDayOfMonth = Date.newInstance(serviceStartDate.year(), serviceStartDate.month(), numberOfDays);
		serviceDays = serviceStartDate.daysBetween(txn.Promoted_End_Date__c);
		serviceDays++;
		c2g__codaJournal__c revenueRecJE = new c2g__codaJournal__c();
		revenueRecJE.c2g__JournalDate__c = lastDayOfMonth;
		revenueRecJE.Additional_Description__c = description;
		revenueRecJE.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Rev_Rec + ' ' + txn.bt_stripe__Transaction_Id__c;
		revenueRecJE.c2g__Reference__c = txn.bt_stripe__Parent_Transaction__c;
		JournalEntryWrapper wrapper = new JournalEntryWrapper();
		wrapper.je = revenueRecJE;
		if (dailyRate * serviceDays == 0)
			return lstWrapper;
		wrapper.lstLines.addAll(createRevRecJELinesForCharge(txn, dailyRate * serviceDays, mapDim3NameToId));
		lstWrapper.add(wrapper);
		return lstWrapper;
	}

	/*
	 * Description: Create Journal Entries for Revenue Recognition
	 * Created    : 02.Feb.2020
	 * Added by   : Plative

	 public static List<JournalEntryWrapper> createRRJEForRefund(bt_stripe__Transaction__c txn,
	 Map<String, Id> mapDim3NameToId){
	 List<JournalEntryWrapper> lstWrapper = new List<JournalEntryWrapper>();
	 Date serviceStartDate, serviceEndDate;
	 serviceStartDate = txn.Promoted_Start_Date__c;
	 serviceEndDate = txn.Promoted_End_Date__c;
	 Integer totalServiceDays = serviceStartDate.daysBetween(serviceEndDate) + 1;
	 Decimal dailyRate = txn.bt_stripe__Amount__c / totalServiceDays;

	 serviceStartDate = System.today();
	 Integer serviceDays = serviceStartDate.daysBetween(serviceEndDate)+1;
	 Integer numberOfDaysOfMonth = Date.daysInMonth(serviceStartDate.year(), serviceStartDate.month());
	 Date lastDayOfMonth = Date.newInstance(serviceStartDate.year(), serviceStartDate.month(), numberOfDaysOfMonth);
	 String description = txn.Patch_ID__c;
	 if(String.isNotBlank(txn.Patch_Shared__c)){
	 description += ','+ txn.Patch_Shared__c.stripHtmlTags();
	 }

	 c2g__codaJournal__c revenueRecJE = new c2g__codaJournal__c();
	 revenueRecJE.c2g__JournalDate__c = lastDayOfMonth ;
	 revenueRecJE.Additional_Description__c = description;
	 revenueRecJE.c2g__JournalDescription__c = System.label.Journal_Description_Prefix_for_Rev_Rec+' '+
	 txn.bt_stripe__Transaction_Id__c;
	 revenueRecJE.c2g__Reference__c = txn.bt_stripe__Parent_Transaction__c;
	 JournalEntryWrapper wrapper = new JournalEntryWrapper();
	 wrapper.je = revenueRecJE;
	 wrapper.lstLines.addAll(createRevRecJELinesForRefund(txn, dailyRate*serviceDays,mapDim3NameToId ));
	 lstWrapper.add(wrapper);
	 serviceStartDate = lastDayOfMonth.addDays(1);
	 return lstWrapper;
	 }**/
	/*
	 * Description: Get GL Account for a given product and Account Type
	 * Created    : 04.Feb.2020
	 * Added by   : Plative
	 */
	public static List<c2g__codaJournalLineItem__c> createRevRecJELinesForCharge(bt_stripe__Transaction__c txn, Decimal amount, Map<String, Id> mapDim3NameToId){
		List<c2g__codaJournalLineItem__c> lstLines = new List<c2g__codaJournalLineItem__c>();
		String productType = txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 
																			  'Patch Membership' : 'Platform';


		//Create line for pnl
		c2g__codaJournalLineItem__c pnlLine = new c2g__codaJournalLineItem__c();
		pnlLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		pnlLine.c2g__AccountAnalysis__c = txn.bt_stripe__Related_Account__c;
		pnlLine.c2g__LineType__c = 'General Ledger Account';
		pnlLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                  'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	pnlLine.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	pnlLine.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	pnlLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		pnlLine.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Profit and Loss');
		pnlLine.c2g__DebitCredit__c = 'Credit';
		pnlLine.c2g__Value__c = 0-amount.setScale(2);
		lstLines.add(pnlLine);

		//Create line for Deferred Revenue
		c2g__codaJournalLineItem__c defRev = new c2g__codaJournalLineItem__c();
		defRev.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		defRev.c2g__AccountAnalysis__c = txn.bt_stripe__Related_Account__c;
		defRev.c2g__LineType__c = 'General Ledger Account';
		defRev.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	defRev.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	defRev.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	defRev.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		defRev.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Deferred Revenue');
		defRev.c2g__DebitCredit__c = 'Debit';
		defRev.c2g__Value__c = amount.setScale(2);
		lstLines.add(defRev);

		return lstLines;
	}

	/*
	 * Description: Get GL Account for a given product and Account Type
	 * Created    : 04.Feb.2020
	 * Added by   : Plative
	 */
	public static List<c2g__codaJournalLineItem__c> createRevRecJELinesForRefund(bt_stripe__Transaction__c txn, Decimal amount, Map<String, Id> mapDim3NameToId){
		List<c2g__codaJournalLineItem__c> lstLines = new List<c2g__codaJournalLineItem__c>();
		String productType = txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ? 
																			  'Patch Membership' : 'Platform';

		//Create line for pnl
		c2g__codaJournalLineItem__c pnlLine = new c2g__codaJournalLineItem__c();
		pnlLine.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		pnlLine.c2g__AccountAnalysis__c = txn.bt_stripe__Related_Account__c;
		pnlLine.c2g__LineType__c = 'General Ledger Account';
		pnlLine.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                  'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	pnlLine.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	pnlLine.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	pnlLine.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		pnlLine.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Profit and Loss');
		pnlLine.c2g__DebitCredit__c = 'Credit';
		pnlLine.c2g__Value__c = 0-amount.setScale(2);
		lstLines.add(pnlLine);

		//Create line for Deferred Revenue
		c2g__codaJournalLineItem__c defRev = new c2g__codaJournalLineItem__c();
		defRev.c2g__LineDescription__c = txn.bt_stripe__Transaction_Id__c;
		defRev.c2g__AccountAnalysis__c = txn.bt_stripe__Related_Account__c;
		defRev.c2g__LineType__c = 'General Ledger Account';
		defRev.c2g__Dimension3__c = mapDim3NameToId.get(txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE') ?
		                                                                                                 'Patch Membership' : txn.bt_stripe__Description__c);
		// if (txn.bt_stripe__Description__c.containsIgnoreCase('INVOICE')){
		// 	defRev.c2g__Dimension3__c = 'Patch Membership';
		// } else if (txn.bt_stripe__Description__c.containsIgnoreCase('Subscription Created')){
		// 	defRev.c2g__Dimension3__c = 'Patch Featured Business';
		// } else{
		// 	defRev.c2g__Dimension3__c = txn.bt_stripe__Description__c;
		// }
		defRev.c2g__GeneralLedgerAccount__c = getGLAccount(productType, 'Deferred Revenue');
		defRev.c2g__DebitCredit__c = 'Debit';
		defRev.c2g__Value__c = amount.setScale(2);
		lstLines.add(defRev);

		return lstLines;
	}

	/*
	 * Description: Get GL Account for a given product and Account Type
	 * Created    : 04.Feb.2020
	 * Added by   : Plative
	 */
	public static Id getGLAccount(String productType, String accType){
		if (lstGLAccountMapping == null){
			lstGLAccountMapping = [SELECT General_Ledger_Account_Name__c, General_Ledger_Account_Type__c, Product_Type__c
			                       FROM General_Ledger_Account_Mapping__mdt];
		}

		General_Ledger_Account_Mapping__mdt filteredMapping;
		for (General_Ledger_Account_Mapping__mdt mapping : lstGLAccountMapping){
			if (((String.isBlank(productType) && (String.isBlank(mapping.Product_Type__c))) || (mapping.Product_Type__c == productType)) && mapping.General_Ledger_Account_Type__c == accType){
				return [SELECT Id
				        FROM c2g__codaGeneralLedgerAccount__c
				        WHERE Name = :mapping.General_Ledger_Account_Name__c
				        LIMIT 1].Id;
			}
		}
		return null;
	}

	/*
	 * Description: Get Dimension 1 record by name
	 * Created    : 04.Feb.2020
	 * Added by   : Plative
	 */
	public static Id getDimension1Record(String dimName){
		return [SELECT Id
		        FROM c2g__codaDimension1__c
		        WHERE Name = :dimName
		        LIMIT 1].Id;
	}

	/*
	 * Description: Get Dimension 3 records by name
	 * Created    : 04.Feb.2020
	 * Added by   : Plative
	 */
	public static Map<String, Id> getDimension3RecordsMap(Set<String> dim3Names){
		Map<String, Id> mapDim3NameToId = new Map<String, Id>();

		for (c2g__codaDimension3__c dim3 : [SELECT Id, Name
		                                    FROM c2g__codaDimension3__c
		                                    WHERE Name IN :dim3Names]){
			mapDim3NameToId.put(dim3.Name, dim3.Id);
		}
		return mapDim3NameToId;
	}

	/*
	 * Description: Get JPM Checking account Id
	 * Created    : 19.Apr.2020
	 * Added by   : Plative
	 */
	private static Id getCheckingBankAccount(){

		return [SELECT Id
		        FROM c2g__codaBankAccount__c
		        WHERE Name = :System.label.Checking_Bank_Account].Id;
	}
}