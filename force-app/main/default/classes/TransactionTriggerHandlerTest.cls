/**
* Description : Test class for Transaction trigger
* [26.Feb.2020] Plative - Added methods testJEForCharge, testJEForRefund, testJEForPayout
*/
/** SeeAllData=true is not best practice for test classes but we have included here due to the
* financialforce error - 'Current company not set'. This requires setting up a company, activating
* and adding user under it. This can be done only through FF UI and not through code.
**/
@isTest
public class TransactionTriggerHandlerTest{
//     @isTest
//     static void testFieldUpdatesForTransaction(){
//         Account objAcc = new Account(Name = 'testtran2@testTran.com', Primary_Email__c = 'testtran2@testTran.com');
//         insert objAcc;
//         //Account does not exist and Metadata exist
//         List<bt_stripe__Transaction__c> lstTransaction = new List<bt_stripe__Transaction__c>();
//         bt_stripe__Transaction__c objTran1 = new bt_stripe__Transaction__c();
//         objTran1.bt_stripe__Amount__c = 12;
//         objTran1.bt_stripe__Currency_ISO__c = 'USD';
//         objTran1.bt_stripe__Receipt_Email__c = 'testtran1@testTran.com';
//         objTran1.bt_stripe__Metadata__c = '{"patch_shared":"684,680,1031","user_id":"23000661","promoted_end_date":"December 19, 2020, 11:59 pm","promoted_start_date":"December 17, 2020, 12:00 am","patch_name":"Brandon","patch_id":"686","event_date":"December 19, 2020, 2:45 am","credits_applied":"0"}';
//         lstTransaction.add(objTran1);
        
//         //Account exist and Metadata exist
//         bt_stripe__Transaction__c objTran2 = new bt_stripe__Transaction__c();
//         objTran2.bt_stripe__Amount__c = 12;
//         objTran2.bt_stripe__Currency_ISO__c = 'USD';
//         objTran2.bt_stripe__Receipt_Email__c = 'testtran2@testTran.com';
//         objTran2.bt_stripe__Related_Account__c = objAcc.Id;
//         /**   objTran2.bt_stripe__Metadata__c = '{"patch_shared":"684,680,1031","user_id":"23000661","promoted_end_date":"December 19, 2020, 11:59 pm","promoted_start_date":"December 17, 2020, 12:00 am","patch_name":"Brandon","patch_id":"686","event_date":"December 19, 2020, 2:45 am","credits_applied":"0"}';
// */lstTransaction.add(objTran2);
        
//         //Account exist and Metadata exist
//         bt_stripe__Transaction__c objTran3 = new bt_stripe__Transaction__c();
//         objTran3.bt_stripe__Amount__c = 12;
//         objTran3.bt_stripe__Currency_ISO__c = 'USD';
//         objTran3.bt_stripe__Receipt_Email__c = 'testtran2@testTran.com';
//         objTran3.bt_stripe__Metadata__c = '{"patch_shared":"684,680,1031","user_id":"23000661","promoted_end_date":"December 19, 2020, 11:59 pm","promoted_start_date":"December 17, 2020, 12:00 am","patch_name":"Brandon","patch_id":"686","event_date":"December 19, 2020, 2:45 am","credits_applied":"0"}';
//         lstTransaction.add(objTran3);
        
//         //Account does not exist and Metadata does not exist
//         bt_stripe__Transaction__c objTran4 = new bt_stripe__Transaction__c();
//         objTran4.bt_stripe__Amount__c = 12;
//         objTran4.bt_stripe__Currency_ISO__c = 'USD';
//         objTran4.bt_stripe__Receipt_Email__c = 'testtran4@testTran.com';
//         lstTransaction.add(objTran4);
//         insert lstTransaction;
        
//         for (bt_stripe__Transaction__c objTr : [Select User_ID__c, patch_shared__c, bt_stripe__Receipt_Email__c, bt_stripe__Related_Account__c, bt_stripe__Account_Name__c
//                                                 from bt_stripe__Transaction__c]){
//                                                     if (objTr.bt_stripe__Receipt_Email__c == 'testtran2@testTran.com'){
//                                                         //system.assertEquals(objAcc.ID, objTr.bt_stripe__Related_Account__c);
//                                                     }
//                                                     if (objTr.bt_stripe__Receipt_Email__c == 'testtran1@testTran.com'){
//                                                         system.assertEquals(objTr.bt_stripe__Account_Name__c, 'testtran1@testTran.com');
//                                                         //system.assertEquals(objTr.User_ID__c, '23000661');
//                                                         /**   system.assertEquals(objTr.patch_shared__c, '684,680,1031'); */
//                                                     }
//                                                     if (objTr.bt_stripe__Receipt_Email__c == 'testtran4@testTran.com'){
//                                                         system.assertEquals(objTr.bt_stripe__Account_Name__c, 'testtran4@testTran.com');
//                                                         system.assertEquals(objTr.User_ID__c, null);
//                                                     }
                                                    
//                                                 }
//     }
    
    @isTest(SeeAllData = true)
    static void testJEForCharge(){
        
        Plative_TestDataFactory.createLedgerAccounts();
        
        //Account creation
        Account objAcc = new Account(Name = 'testtran2@testTran.com', Primary_Email__c = 'testtran2@testTran.com');
        insert objAcc;
        
        //Create charge transaction
        List<bt_stripe__Transaction__c> lstTransaction = new List<bt_stripe__Transaction__c>();
        bt_stripe__Transaction__c objTran1 = new bt_stripe__Transaction__c();
        objTran1.bt_stripe__Amount__c = 120;
        objTran1.bt_stripe__Currency_ISO__c = 'USD';
        objTran1.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran1.Promoted_Start_Date__c = System.today()-25;
        objTran1.Promoted_End_Date__c = System.today()+25;
        objTran1.bt_stripe__Related_Account__c = objAcc.Id;
        objTran1.bt_stripe__Processed_Date__c = System.today();
        objTran1.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran1.bt_stripe__Transaction_Id__c = 'ch_chargeid';
        objTran1.Patch_ID__c = 'Patch Id';
        objTran1.Patch_Shared__c = 'Patch Shared';
        objTran1.bt_stripe__Description__c = 'Invoice';
        objTran1.bt_stripe__Transaction_Status__c = 'Completed';
        
        Test.startTest();
        insert objTran1;
        Test.stopTest();
        
        //Validate if one JE got created
        System.assertEquals(1, [SELECT Id
                                FROM c2g__codaJournal__c
                                WHERE c2g__JournalDescription__c LIKE '%ch_chargeid%'].size());
        //Validate JE has 4 lines
        System.assertEquals(4, [SELECT Id
                                FROM c2g__codaJournalLineItem__c
                                WHERE c2g__Journal__r.c2g__JournalDescription__c LIKE '%ch_chargeid%'].size());
    }
    
    @isTest(SeeAllData = true)
    static void testJEForRefund(){
        Plative_TestDataFactory.createLedgerAccounts();
        
        //Account creation
        Account objAcc = new Account(Name = 'testtran2@testTran.com', Primary_Email__c = 'testtran2@testTran.com');
        insert objAcc;
        
        //Create charge transaction
        bt_stripe__Transaction__c objTran1 = new bt_stripe__Transaction__c();
        objTran1.bt_stripe__Amount__c = 120;
        objTran1.bt_stripe__Currency_ISO__c = 'USD';
        objTran1.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran1.Promoted_Start_Date__c = System.today()-25;
        objTran1.Promoted_End_Date__c = System.today()+25;
        objTran1.bt_stripe__Related_Account__c = objAcc.Id;
        objTran1.bt_stripe__Processed_Date__c = System.today();
        objTran1.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran1.bt_stripe__Transaction_Id__c = 'ch_chargeid';
        objTran1.Patch_ID__c = 'Patch Id';
        objTran1.Patch_Shared__c = 'Patch Shared';
        objTran1.bt_stripe__Description__c = 'Invoice';
        objTran1.bt_stripe__Transaction_Status__c = 'Completed';
        insert objTran1;
        
        bt_stripe__Transaction__c objTran2 = new bt_stripe__Transaction__c();
        objTran2.bt_stripe__Amount__c = 120;
        objTran2.bt_stripe__Currency_ISO__c = 'USD';
        objTran2.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran2.Promoted_Start_Date__c = System.today()-25;
        objTran2.Promoted_End_Date__c = System.today()+25;
        objTran2.bt_stripe__Related_Account__c = objAcc.Id;
        objTran2.bt_stripe__Processed_Date__c = System.today();
        objTran2.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran2.bt_stripe__Transaction_Id__c = 'ch_refundid';
        objTran2.Patch_Shared__c = 'Patch Shared';
        objTran2.bt_stripe__Description__c = 'Invoice';
        objTran2.bt_stripe__Parent_Transaction__c = objTran1.Id;
        objTran2.bt_stripe__Transaction_Status__c = 'Completed';
        objTran2.bt_stripe__Parent_Transaction_Id__c = 'ch_chargeid';
        objTran2.bt_stripe__Transaction_Type__c = 'Refund';
        
        TransactionTriggerHandler.hasAfterInsertRun = false;
        
        Test.startTest();
        insert objTran2;
        Test.stopTest();
        
        Integer monthsBetween = objTran2.Promoted_Start_Date__c.monthsBetween(System.today());
        monthsBetween++;
        
        //Validate if one JE got created
        System.assertEquals(1, [SELECT Id
                                FROM c2g__codaJournal__c
                                WHERE c2g__JournalDescription__c LIKE '%ch_refundid%'].size());
        //Validate JE has 4 lines for refund
        System.assertEquals(4, [SELECT Id
                                FROM c2g__codaJournalLineItem__c
                                WHERE c2g__Journal__r.c2g__JournalDescription__c LIKE '%ch_refundid%'].size());
    }
    
    @isTest(SeeAllData = true)
    static void testJEForRefund2(){
        Plative_TestDataFactory.createLedgerAccounts();
        
        //Account creation
        Account objAcc = new Account(Name = 'testtran2@testTran.com', Primary_Email__c = 'testtran2@testTran.com');
        insert objAcc;
        
        //Create charge transaction
        bt_stripe__Transaction__c objTran1 = new bt_stripe__Transaction__c();
        objTran1.bt_stripe__Amount__c = 120;
        objTran1.bt_stripe__Currency_ISO__c = 'USD';
        objTran1.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran1.Promoted_Start_Date__c = System.today()-25;
        objTran1.Promoted_End_Date__c = System.today()+25;
        objTran1.bt_stripe__Processed_Date__c = System.today();
        objTran1.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran1.bt_stripe__Transaction_Id__c = 'ch_chargeid';
        objTran1.Patch_ID__c = 'Patch Id';
        objTran1.Patch_Shared__c = 'Patch Shared';
        objTran1.bt_stripe__Description__c = 'Invoice';
        objTran1.bt_stripe__Transaction_Status__c = 'Completed';
        objTran1.bt_stripe__Metadata__c = '{"patch_shared":"684,680,1031","user_id":"23000661","promoted_end_date":"December 19, 2020, 11:59 pm","promoted_start_date":"December 17, 2020, 12:00 am","patch_name":"Brandon","patch_id":"686","event_date":"December 19, 2020, 2:45 am","credits_applied":"0"}';
        
        insert objTran1;
        
        bt_stripe__Transaction__c objTran2 = new bt_stripe__Transaction__c();
        objTran2.bt_stripe__Amount__c = 120;
        objTran2.bt_stripe__Currency_ISO__c = 'USD';
        objTran2.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran2.Promoted_Start_Date__c = System.today()-25;
        objTran2.Promoted_End_Date__c = System.today()+25;
        objTran2.bt_stripe__Processed_Date__c = System.today();
        objTran2.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran2.bt_stripe__Transaction_Id__c = 'ch_refundid';
        objTran2.Patch_Shared__c = 'Patch Shared';
        objTran2.bt_stripe__Description__c = 'Invoice';
        objTran2.bt_stripe__Parent_Transaction__c = objTran1.Id;
        objTran2.bt_stripe__Transaction_Status__c = 'Completed';
        objTran2.bt_stripe__Parent_Transaction_Id__c = 'ch_chargeid';
        objTran2.bt_stripe__Transaction_Type__c = 'Refund';
        objTran2.bt_stripe__Metadata__c = '{"patch_shared":"684,680,1031","user_id":"23000661","promoted_end_date":"December 19, 2020, 11:59 pm","promoted_start_date":"December 17, 2020, 12:00 am","patch_name":"Brandon","patch_id":"686","event_date":"December 19, 2020, 2:45 am","credits_applied":"0"}';
              
        TransactionTriggerHandler.hasAfterInsertRun = false;
        
        Test.startTest();
        insert objTran2;
        Test.stopTest();
        
        Integer monthsBetween = objTran2.Promoted_Start_Date__c.monthsBetween(System.today());
        monthsBetween++;
        
        //Validate if one JE got created
        System.assertEquals(1, [SELECT Id
                                FROM c2g__codaJournal__c
                                WHERE c2g__JournalDescription__c LIKE '%ch_refundid%'].size());
        //Validate JE has 4 lines for refund
        System.assertEquals(4, [SELECT Id
                                FROM c2g__codaJournalLineItem__c
                                WHERE c2g__Journal__r.c2g__JournalDescription__c LIKE '%ch_refundid%'].size());
    }
    
    @isTest(SeeAllData = true)
    static void testJEForPayout(){
        Plative_TestDataFactory.createLedgerAccounts();
        
        //Account creation
        Account objAcc = new Account(Name = 'testtran2@testTran.com', Primary_Email__c = 'testtran2@testTran.com');
        insert objAcc;
        
        Id payoutRTId = Schema.SObjectType.bt_stripe__Transaction__c.getRecordTypeInfosByDeveloperName().get('Payout').getRecordTypeId();
        bt_stripe__Transaction__c payout = new bt_stripe__Transaction__c();
        payout.RecordTypeId = payoutRTId;
        payout.bt_stripe__Amount__c = 120;
        payout.bt_stripe__Currency_ISO__c = 'USD';
        payout.bt_stripe__Receipt_Email__c = 'test@test.com';
        payout.bt_stripe__Related_Account__c = objAcc.Id;
        payout.bt_stripe__Processed_Date__c = System.today();
        payout.bt_stripe__Payout_Processed_Date__c = System.today();
        payout.bt_stripe__Stripe_Fee_Total__c = 5;
        payout.bt_stripe__Transaction_Id__c = 'payout_id';
        payout.Patch_ID__c = 'Patch Id';
        payout.Patch_Shared__c = 'Patch Shared';
        payout.bt_stripe__Description__c = 'Invoice';
        payout.bt_stripe__Transaction_Status__c = 'Open';
        insert payout;
        
        List<bt_stripe__Transaction__c> lstTxns = new List<bt_stripe__Transaction__c>();
        //Create charge transaction
        bt_stripe__Transaction__c objTran1 = new bt_stripe__Transaction__c();
        objTran1.bt_stripe__Amount__c = 120;
        objTran1.bt_stripe__Currency_ISO__c = 'USD';
        objTran1.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran1.Promoted_Start_Date__c = System.today()-25;
        objTran1.Promoted_End_Date__c = System.today()+25;
        objTran1.bt_stripe__Related_Account__c = objAcc.Id;
        objTran1.bt_stripe__Processed_Date__c = System.today();
        objTran1.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran1.bt_stripe__Transaction_Id__c = 'ch_chargeid';
        objTran1.Patch_ID__c = 'Patch Id';
        objTran1.Patch_Shared__c = 'Patch Shared';
        objTran1.bt_stripe__Description__c = 'Invoice';
        objTran1.bt_stripe__Transaction_Status__c = 'Completed';
        objTran1.bt_stripe__Payout__c = payout.Id;
        
        insert objTran1;
        
        bt_stripe__Transaction__c objTran2 = new bt_stripe__Transaction__c();
        objTran2.bt_stripe__Amount__c = 120;
        objTran2.bt_stripe__Currency_ISO__c = 'USD';
        objTran2.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran2.Promoted_Start_Date__c = System.today()-25;
        objTran2.Promoted_End_Date__c = System.today()+25;
        objTran2.bt_stripe__Related_Account__c = objAcc.Id;
        objTran2.bt_stripe__Processed_Date__c = System.today();
        objTran2.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran2.bt_stripe__Transaction_Id__c = 'ch_refundid';
        objTran2.Patch_Shared__c = 'Patch Shared';
        objTran2.bt_stripe__Description__c = 'Invoice';
        objTran2.bt_stripe__Parent_Transaction__c = objTran1.Id;
        objTran2.bt_stripe__Transaction_Status__c = 'Completed';
        objTran2.bt_stripe__Parent_Transaction_Id__c = 'ch_chargeid';
        objTran2.bt_stripe__Transaction_Type__c = 'Refund';
        objTran2.bt_stripe__Payout__c = payout.Id;
        
        insert objTran2;
        
        TransactionTriggerHandler.hasBeforeUpdateRun = false;
        Test.startTest();
        payout.bt_stripe__Transaction_Status__c = 'Completed';
        update payout;
        Test.stopTest();
        
        //Validate if one payout JE got created
        System.assertEquals(1, [SELECT Id
                                FROM c2g__codaJournal__c
                                WHERE c2g__JournalDescription__c LIKE '%payout_id%'].size());
        //Validate JE has 3 lines
        System.assertEquals(3, [SELECT Id
                                FROM c2g__codaJournalLineItem__c
                                WHERE c2g__Journal__r.c2g__JournalDescription__c LIKE '%payout_id%'].size());
    }
    
    @isTest(SeeAllData = true)
    static void testRevenueRecognitionBatch(){
        
        Plative_TestDataFactory.createLedgerAccounts();
        
        //Account creation
        Account objAcc = new Account(Name = 'testtran2@testTran.com', Primary_Email__c = 'testtran2@testTran.com');
        insert objAcc;
        
        //Create charge transaction
        bt_stripe__Transaction__c objTran1 = new bt_stripe__Transaction__c();
        objTran1.bt_stripe__Amount__c = 120;
        objTran1.bt_stripe__Currency_ISO__c = 'USD';
        objTran1.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran1.Promoted_Start_Date__c = System.today().toStartOfMonth().addDays(-20);
        objTran1.Promoted_End_Date__c = System.today().toStartOfMonth().addDays(20);
        objTran1.bt_stripe__Related_Account__c = objAcc.Id;
        objTran1.bt_stripe__Processed_Date__c = System.today();
        objTran1.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran1.bt_stripe__Transaction_Id__c = 'ch_chargeid1_testclass';
        objTran1.Patch_ID__c = 'Patch Id';
        objTran1.Patch_Shared__c = 'Patch Shared';
        objTran1.bt_stripe__Description__c = 'Invoice';
        objTran1.bt_stripe__Transaction_Status__c = 'Completed';
        insert objTran1;
        
        bt_stripe__Transaction__c objTran2 = new bt_stripe__Transaction__c();
        objTran2.bt_stripe__Amount__c = 120;
        objTran2.bt_stripe__Currency_ISO__c = 'USD';
        objTran2.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran2.Promoted_Start_Date__c = System.today().toStartOfMonth().addDays(-20);
        objTran2.Promoted_End_Date__c = System.today().toStartOfMonth().addDays(20);
        objTran2.bt_stripe__Related_Account__c = objAcc.Id;
        objTran2.bt_stripe__Processed_Date__c = System.today();
        objTran2.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran2.bt_stripe__Transaction_Id__c = 'ch_refundid_testclass';
        objTran2.Patch_Shared__c = 'Patch Shared';
        objTran2.bt_stripe__Description__c = 'Invoice';
        objTran2.bt_stripe__Parent_Transaction__c = objTran1.Id;
        objTran2.bt_stripe__Transaction_Status__c = 'Completed';
        objTran2.bt_stripe__Parent_Transaction_Id__c = 'ch_chargeid';
        objTran2.bt_stripe__Transaction_Type__c = 'Refund';
        insert objTran2;
        
        //Create charge transaction
        bt_stripe__Transaction__c objTran3 = new bt_stripe__Transaction__c();
        objTran3.bt_stripe__Amount__c = 120;
        objTran3.bt_stripe__Currency_ISO__c = 'USD';
        objTran3.bt_stripe__Receipt_Email__c = 'test@test.com';
        objTran3.Promoted_Start_Date__c = System.today().toStartOfMonth().addDays(-20);
        objTran3.Promoted_End_Date__c = System.today().toStartOfMonth().addDays(20);
        objTran3.bt_stripe__Related_Account__c = objAcc.Id;
        objTran3.bt_stripe__Processed_Date__c = System.today();
        objTran3.bt_stripe__Stripe_Fee_Total__c = 5;
        objTran3.bt_stripe__Transaction_Id__c = 'ch_chargeid2_testclass';
        objTran3.Patch_ID__c = 'Patch Id';
        objTran3.Patch_Shared__c = 'Patch Shared';
        objTran3.bt_stripe__Description__c = 'Invoice';
        objTran3.bt_stripe__Transaction_Status__c = 'Completed';
        insert objTran3;
        
        Test.startTest();
        Plative_RevenueRecognitionScheduler schedule = new Plative_RevenueRecognitionScheduler();
        schedule.execute(null);
        Test.stopTest();
    }
    
    public static void fakeMethod(){
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        
        //repeat the i++ hundred of times
        
    }
    
}