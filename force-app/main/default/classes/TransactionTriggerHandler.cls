/**
 * Description : Handles DML events for Transaction trigger
 * [02.Feb.2020] Plative - Added after insert trigger & before update handler method
 */
public without sharing class TransactionTriggerHandler{
	public static boolean hasBeforeUpdateRun = false;
	public static boolean hasAfterInsertRun = false;
	/*
	 * Description: On After Insert DML
	 * Created     : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static void onAfterInsert(List<bt_stripe__Transaction__c> lstNewTrx){
		for (bt_stripe__Transaction__c objTran : lstNewTrx){
			// if the description field "bt_stripe__Description__c"  is not blank
			// if (String.isNotBlank(objTran.bt_stripe__Description__c)){
				// System.debug('After InsertTrigger Runs');
				if (!TransactionTriggerHandler.hasAfterInsertRun){
					TransactionTriggerHelperNew.processTransactionsByType(lstNewTrx, null);
				}
				TransactionTriggerHandler.hasAfterInsertRun = true;
			// } else{
			// 	System.debug('1. The description field "bt_stripe__Description__c" is blank');
			// }
		}
	}

	/*
	 * Description: On After Update DML
	 * Created     : 02.Feb.2020
	 * Added by   : Plative
	 */
	public static void onBeforeUpdate(List<bt_stripe__Transaction__c> lstNewTrx, Map<Id, bt_stripe__Transaction__c> mapOldTxns){
		for (bt_stripe__Transaction__c objTran : lstNewTrx){
			// if the description field "bt_stripe__Description__c"  is not blank
			// if (String.isNotBlank(objTran.bt_stripe__Description__c)){
				// System.debug('Update Trigger Runs');
				if (!TransactionTriggerHandler.hasBeforeUpdateRun){
					TransactionTriggerHelperNew.processTransactionsByType(lstNewTrx, mapOldTxns);
				}
				TransactionTriggerHandler.hasBeforeUpdateRun = true;
			// } else{
			// 	System.debug('2. The description field "bt_stripe__Description__c" is blank');
			// }
		}
	}

	//Method to update transaction related fields on insert of transaction record.
	public static void onBeforeInsert(List<bt_stripe__Transaction__c> lstNewTransaction){
		for (bt_stripe__Transaction__c objTran : lstNewTransaction){
			// if the description field "bt_stripe__Description__c"  is not blank
			// if (String.isNotBlank(objTran.bt_stripe__Description__c)){
				// System.debug('Befrore Insert Trigger Runs');
				try{
					Set<String> setEmails = new Set<String>();
					Map<String, String> mapRelatedAccount = new Map<String, String>();
					Set<String> recordTypeIds = new Set<String>();
					recordTypeIds.add(Schema.SObjectType.bt_stripe__Transaction__c.getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId());
					recordTypeIds.add(Schema.SObjectType.bt_stripe__Transaction__c.getRecordTypeInfosByDeveloperName().get('Payout').getRecordTypeId());
					for (bt_stripe__Transaction__c objTransaction : lstNewTransaction){
						//Filter Transaction records where related Account is null.
						System.debug('bt_stripe__Related_Account__c ' + objTransaction.bt_stripe__Related_Account__c); 
	                    System.debug('bt_stripe__Receipt_Email__c ' + objTransaction.bt_stripe__Receipt_Email__c);
                        System.debug(recordTypeIds.contains(objTransaction.recordtypeid));
						if (objTransaction.bt_stripe__Related_Account__c == null && objTransaction.bt_stripe__Receipt_Email__c != null && recordTypeIds.contains(objTransaction.recordtypeid)){
							setEmails.add(objTransaction.bt_stripe__Receipt_Email__c);
						}
					}
					if (setEmails.size() > 0){
						//Fetch Account Mappings for primary emails.
						mapRelatedAccount = fetchAccounts(setEmails);
					}
					//Update related Account and metadata details on the transaction.
					for (bt_stripe__Transaction__c objTransaction : lstNewTransaction){
						if (objTransaction.bt_stripe__Related_Account__c == null && objTransaction.bt_stripe__Receipt_Email__c != null && mapRelatedAccount.containsKey(objTransaction.bt_stripe__Receipt_Email__c)){
							objTransaction.bt_stripe__Related_Account__c = mapRelatedAccount.get(objTransaction.bt_stripe__Receipt_Email__c);
						}
						if (objTransaction.bt_stripe__Metadata__c != null){
							FlowInputParser fpObj = FlowInputParser.parse(objTransaction.bt_stripe__Metadata__c);
							//bt_stripe__Transaction__c newTransObj= new bt_stripe__Transaction__c();
							//objTransaction.Id=transObj2.Id;
							objTransaction.User_ID__c = fpObj.user_id;
							objTransaction.Patch_ID__c = fpobj.patch_id;
							objTransaction.Patch_Name__c = fpobj.patch_name;
							objTransaction.Credits_Applied__c = fpObj.credits_applied;
							//objTransaction.Patches_Shared2__c=fpObj.patches_shared2;
							objTransaction.Patch_Shared__c = fpObj.patch_shared;
							objTransaction.Event_Date__c = UtilityWork.parseDateString(fpObj.event_date);
							objTransaction.Promoted_Start_Date__c = UtilityWork.parseDateString(fpObj.promoted_start_date);
							objTransaction.Promoted_End_Date__c = UtilityWork.parseDateString(fpObj.promoted_end_date);
						}
					}
				} catch (Exception e){
					throw e;
				}
			// } else{
			// 	System.debug('3. The description field "bt_stripe__Description__c" is blank');
			// }
		}
	}

	//Method to fetch existing account for the Primary_Email__c, if not found create new Account record.
	public static Map<String, String> fetchAccounts(Set<String> setEmails){
		Map<String, String> mapRelatedAccount = new Map<String, String>();
		List<Account> lstNewAccount = new List<Account>();
		//Query Existing Account
		for (Account objAccount : [Select Id, Primary_Email__c
		                           from Account
		                           where Primary_Email__c IN :setEmails]){
			mapRelatedAccount.put(objAccount.Primary_Email__c, objAccount.Id);
		}
		for (String emails : setEmails){
			if (!mapRelatedAccount.containsKey(emails.tolowercase())){
				//Create new account for emails where account do not exist
				lstNewAccount.add(new Account(Name = emails, Primary_Email__c = emails));
			}
		}
		if (lstNewAccount.size() > 0){
			insert lstNewAccount;
			for (Account newAccount : lstNewAccount){
				mapRelatedAccount.put(newAccount.Primary_Email__c, newAccount.Id);
			}
		}
		return mapRelatedAccount;
	}
}