/**
 * Description : Trigger on Transaction object
 * [02.Feb.2020] Plative - Added method to be invoked after insert & update
 */
trigger TransactionTriggerHandler on bt_stripe__Transaction__c(before insert, after insert, before update ){

	Trigger_Settings__c triggerSwitch = Trigger_Settings__c.getOrgDefaults();

	if (Trigger.isBefore){
		TransactionTriggerHandler.onBeforeInsert(Trigger.New);
	}

	if (triggerSwitch.Transaction__c && Trigger.isAfter && Trigger.isInsert){
		TransactionTriggerHandler.onAfterInsert(Trigger.new);
	}
	if (triggerSwitch.Transaction__c && Trigger.isBefore && Trigger.isUpdate){
		TransactionTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
	}
	/*list<bt_stripe__Transaction__c> transactionList = trigger.new;
	 Set <Id> Ids = new Set<Id>();


	 for(bt_stripe__Transaction__c transObj:Trigger.new){
	 Ids.add(transObj.Id);
	 }

	 List<bt_stripe__Transaction__c> transList=[select id,bt_stripe__Metadata__c,recordTypeId,bt_stripe__Receipt_Email__c,bt_stripe__Related_Account__c from bt_stripe__Transaction__c where id IN : Ids];
	 /*Map<String,Id> emailMap= new Map <String,Id>();

	 for(bt_stripe__Transaction__c transObj2: transList){
	 if(transobj2.bt_stripe__Receipt_Email__c!=null)
	 emailMap.put(transobj2.bt_stripe__Receipt_Email__c,transObj2.Id);
	 }

	 List<Account> existingAccountList=new List<Account>([select primary_email__c,id,name from Account where primary_email__c IN : emailMap.keyset()]);
	 Map<String,Account> existingAccountMap=new Map<String,Account>();
	 for(Account accObj:existingAccountlist){
	 existingAccountMap.put(accObj.Primary_Email__c, accObj);
	 }
	 */
	/*List<bt_stripe__Transaction__c> newTransList= new List<bt_stripe__Transaction__c> ();
	 Map<ID,recordtype> recTypeMap = new Map<ID, recordtype>([select id,developername from recordtype where sobjectType='bt_stripe__Transaction__c' and (developername='Charge' or developername='Payout')]);

	 List<bt_stripe__Transaction__c> transList2= new List<bt_stripe__Transaction__c> ();

	 for(bt_stripe__Transaction__c transObj2: transList){
	 try{
	 String metadataRecord=transObj2.bt_stripe__Metadata__c;
	 if(metadataRecord!=null && metadataRecord!='')
	 {

	 FlowInputParser fpObj= FlowInputParser.parse(metadataRecord);
	 bt_stripe__Transaction__c newTransObj= new bt_stripe__Transaction__c();
	 newTransObj.Id=transObj2.Id;
	 newTransObj.User_ID__c=fpObj.user_id;
	 newTransObj.Patch_ID__c=fpobj.patch_id;
	 newTransObj.Patch_Name__c=fpobj.patch_name;
	 newTransObj.Credits_Applied__c=fpObj.credits_applied;
	 newTransObj.Patches_Shared2__c=fpObj.patches_shared2;
	 newTransObj.Event_Date__c=UtilityWork.parseDateString(fpObj.event_date);
	 newTransObj.Promoted_Start_Date__c=UtilityWork.parseDateString(fpObj.promoted_start_date);
	 newTransObj.Promoted_End_Date__c=UtilityWork.parseDateString(fpObj.promoted_end_date);

	 newTranslist.add(newTransObj);
	 }


	 }
	 catch(exception e){
	 throw e;
	 }
	 }

	 update newTranslist;*/
}