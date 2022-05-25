import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { constructErrorMessage, showToast} from "c/utilCommon";
import refundPaymentTitle from "@salesforce/label/c.pmtRefundPaymentTitle";
import refundAmount from "@salesforce/label/c.pmtRefundAmount";
import refundPaymentDate from "@salesforce/label/c.pmtRefundPaymentDate";
import refundPaymentConfirmButton from "@salesforce/label/c.pmtRefundPaymentConfirmedButton";
import cancelButtonLabel from "@salesforce/label/c.stgBtnCancel";
import commonRefreshPage from "@salesforce/label/c.commonRefreshPage";
import noRefundPermissionMessage from "@salesforce/label/c.pmtNoRefundPermissionMessage";
import refundPaymentErrorMessage from "@salesforce/label/c.pmtRefundPaymentErrorMessage";
import refundPaymentMessage from "@salesforce/label/c.pmtRefundPaymentMessage";
import refundProcessing from "@salesforce/label/c.pmtRefundProcessing";

import processRefund from "@salesforce/apex/PMT_RefundController.processRefund";
import getPermissionData from "@salesforce/apex/PMT_RefundController.getPermissionData";

import PAYMENT_AMOUNT_FIELD from '@salesforce/schema/npe01__oppPayment__c.npe01__Payment_Amount__c';
import PAYMENT_DATE_FIELD from '@salesforce/schema/npe01__oppPayment__c.npe01__Payment_Date__c';

export default class refundPayment extends LightningElement {
    @api recordId;
    hasError = false;
    errorMessage;
    labels = Object.freeze({
        refundPaymentTitle,
        refundPaymentConfirmButton,
        cancelButtonLabel,
        commonRefreshPage,
        noRefundPermissionMessage,
        refundPaymentMessage,
        refundAmount,
        refundPaymentDate,
        refundProcessing,
        refundPaymentErrorMessage
    });
    refundView;
    paymentAmount;
    paymentDate;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [PAYMENT_AMOUNT_FIELD, PAYMENT_DATE_FIELD]})
    wiredRecord({ error, data }) {
        if (error) {
            this.hasError = true;
            this.errorMessage = constructErrorMessage(error).detail;
        } else if (data) {
            this.paymentAmount = getFieldValue(data, PAYMENT_AMOUNT_FIELD);
            this.paymentDate = getFieldValue(data, PAYMENT_DATE_FIELD);
        }
    }

    async connectedCallback() {
        try {
            this.refundView = await getPermissionData();
            if (this.refundView.hasRequiredPermissions === false) {
                this.displayErrorMessage(this.labels.noRefundPermissionMessage);
            }

        }catch (ex) {
            this.displayErrorMessage(constructErrorMessage(ex).detail);
        }
    }

    handleRefund() {
        processRefund({
            paymentId: this.recordId
        }) 
            .then((response) => {
                this.processResponse(response);
        })
        .catch((error) => {
            this.displayErrorMessage(constructErrorMessage(error).detail);
        });

    }

    handleClose(){
        this.dispatchEvent( new CloseActionScreenEvent() );
    }

    processResponse(response) {
        if (response.hasRequiredPermissions === false) {
            this.displayErrorMessage(this.labels.noRefundPermissionMessage);
            return;

        } else if (response.isSuccess === true) {
            showToast('', this.labels.refundProcessing + ' {0}', 'info', '', [
                {
                    url: '/' + response.redirectToPaymentId,
                    label: this.labels.commonRefreshPage,
                }]
            );

        } else if (response.isSuccess === false) {
            showToast(this.labels.refundPaymentErrorMessage, response.errorMessage, 'error');
        }
        
        this.handleClose();
    }

    displayErrorMessage(errorMessage) {
        this.hasError = true;
        this.errorMessage = errorMessage;
    }
}