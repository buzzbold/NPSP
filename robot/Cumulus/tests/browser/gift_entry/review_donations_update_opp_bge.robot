*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/GiftEntryPageObject.py
...             robot/Cumulus/resources/OpportunityPageObject.py
...             robot/Cumulus/resources/PaymentPageObject.py
...             robot/Cumulus/resources/AccountPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             API Check And Enable Gift Entry
...             Setup Test Data
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Keywords ***
Setup Test Data
    [Documentation]      Creates the contact and opportunity record required for the test
    ...                  along with getting dates and namespace required for test.
    &{CONTACT} =         API Create Contact       FirstName=${faker.first_name()}    LastName=${faker.last_name()}
    Set suite variable   &{CONTACT}
    ${FUT_DATE} =        Get Current Date         result_format=%Y-%m-%d    increment=2 days
    Set suite variable   ${FUT_DATE}
    ${CUR_DATE} =        Get Current Date         result_format=%Y-%m-%d
    Set suite variable   ${CUR_DATE}
    &{OPPORTUNITY} =     API Create Opportunity   ${CONTACT}[AccountId]              Donation
    ...                  StageName=Prospecting
    ...                  Amount=100
    ...                  CloseDate=${FUT_DATE}
    ...                  npe01__Do_Not_Automatically_Create_Payment__c=false
    ...                  Name=${CONTACT}[Name] Donation
    Set suite variable   &{OPPORTUNITY}
    ${UI_DATE} =         Get Current Date                   result_format=%b %-d, %Y
    Set suite variable   ${UI_DATE}
    ${NS} =              Get NPSP Namespace Prefix
    Set suite variable   ${NS}

*** Test Cases ***
Review Donation And Update Opportunity For Batch Gift
    # [Documentation]                      Create an organization account with open opportunity (with payment record) via API. Go to SGE form
    # ...                                  select the donor as account and the account created. Verify review donations modal and select to update payment.
    # ...                                  Change date to today and payment amount to be less than opp amount. Verify that same payment record got updated
    # ...                                  with new amount and date but opportunity is still prospecting and amount is not updated.
    [tags]                               unstable      feature:GE                    W-042803
    #verify Review Donations link is available and update a payment
    Go To Page                           Landing                       GE_Gift_Entry
    Click Gift Entry Button              New Batch
    Wait Until Modal Is Open
    Select Template                      Default Gift Entry Template
    Load Page Object                     Form                          Gift Entry
    Fill Gift Entry Form
    ...                                  Batch Name=${CONTACT}[Name]Automation Batch
    ...                                  Batch Description=This is a test batch created via automation script
    Click Gift Entry Button              Next
    Click Gift Entry Button              Save
    Current Page Should Be               Form                          Gift Entry
    ${batch_id} =                        Save Current Record ID For Deletion     ${NS}DataImportBatch__c
    Fill Gift Entry Form
    ...                                  Donor Type=Contact1
    ...                                  Existing Donor Contact=${CONTACT}[Name]
    Click Button                         Review Donations
    Wait Until Modal Is Open
    Verify Link Status
    ...                                  Update this Payment=enabled
    ...                                  Update this Opportunity=disabled
    &{new_payment} =                     API Create Payment            ${OPPORTUNITY}[Id]
    ...                                  npe01__Payment_Amount__c=50.0
    ...                                  npe01__Scheduled_Date__c=${CUR_DATE}
    Reload Page
    Current Page Should Be               Form                          Gift Entry
    Fill Gift Entry Form
    ...                                  Donor Type=Contact1
    ...                                  Existing Donor Contact=${CONTACT}[Name]
    Click Button                         Review Donations
    Wait Until Modal Is Open
    Verify Link Status                   Update this Opportunity=enabled
    Click Button                         Update this Opportunity
    Wait Until Modal Is Closed
    Fill Gift Entry Form
    ...                                  Donation Amount=80
    ...                                  Donation Date=Today
    Click Button                         Save & Enter New Gift
    #verify donation date and amount values changed on table
    Verify Gift Count                    1
    Verify Table Field Values            Batch Gifts
    ...                                  Donor Name=${CONTACT}[Name]
    ...                                  Donation Amount=$80.00
    ...                                  Donation Name=${OPPORTUNITY}[Name]
    ...                                  Donation Date=${UI_DATE}
    Scroll Page To Location              0      0
    Click Gift Entry Button              Process Batch
    Click Data Import Button             NPSP Data Import                button       Begin Data Import Process
    Wait For Batch To Process            BDI_DataImport_BATCH            Completed
    Click Button With Value              Close
    #verify opportunity record is updated with new amount and date and is closed won
    Verify Expected Values               nonns                          Opportunity    ${OPPORTUNITY}[Id]
    ...                                  Amount=80.0
    ...                                  CloseDate=${CUR_DATE}
    ...                                  StageName=Closed Won
