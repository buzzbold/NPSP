@RestResource(urlMapping='/pkbanding')
global with sharing class pkBandingService {

    // consts
    public static final String ERR_CLASS_NAME = 'pkBandingService:';
    public static final Integer HTTP_SUCCESS = 200;
    public static final Integer HTTP_FORBIDDEN = 403;

    @HttpPost
    global static void pkbanding() {

        // set default response
        RestResponse response = RestContext.response;
        response.statusCode = HTTP_SUCCESS;

        // aux vars
        Cursor request;
        dispatcherResponse dResponse = new dispatcherResponse();
        SObject[] events;

        // class vars
        Integer recordCount = 0;
        Integer successCount = 0;
        Integer failedCount = 0;
        Set<String> failedIds = new Set<String>();
        
        // aux vars
        Integer band;        
        Integer numberOfEvents;
        Integer eventLimit;
        String lastOffset;        

        try { system.debug('init service');

            // deserialize payload
            request = (Cursor) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                Cursor.class
            ); 
            system.debug('request data:' + request);

            // init aux vars
            numberOfEvents = 0;
            band = request.band;
            eventLimit = request.batchSize;
            lastOffset = request.offset;

            // init response
            dResponse.init(request);

            // init pk banding service
            UTIL_pkBanding pkb = new UTIL_pkBanding();
            // set resp obj
            pkb.resp = dResponse;
            // get next batch
            events = pkb.getNextBatch(); system.debug('events results: ' + events); system.debug('events size: ' + events.size());
            // get resp obj from service
            dResponse = pkb.resp;
            dResponse.numberProcessed = events.size(); system.debug('dResponse: ' + dResponse);

            // process RDs if result == true
            if (dResponse.numberProcessed>0 && dResponse.result) { system.debug('calling RD method...');

                // counter of RDs to process
                recordCount = events.size();
                System.debug('recordCount: ' + recordCount);

                // disable rollups
                TDTM_Config_API.disableAllRollupTriggers();
                // execute RD service
                RD2_OpportunityEvaluationService evalService = new RD2_OpportunityEvaluationService()
                                                                    .withBatchContext()
                                                                    .withRds(UTIL_SObject.extractIds(events))
                                                                    .withCurrentDate(Date.Today())
                                                                    .evaluateOpportunities();

                // todo: maybe get ids to replay

                // counter after execution                
                failedCount += evalService.getRecordsFailed();   System.debug('rdIds size: ' + evalService.rdIds.size());  System.debug('failedCount: ' + failedCount);            
                successCount += evalService.rdIds.size() - evalService.getRecordsFailed(); System.debug('successCount: ' + successCount);            

            } 

        } catch (Exception e) {
            System.debug('EXCEPTION: ' + e.getMessage());
            // update response object
            dResponse.cursor.offset = lastOffset;
            dResponse.numberProcessed = numberOfEvents; // TODO: accomodate this number
            dResponse.result = false;
            dResponse.error =  ERR_CLASS_NAME + e.getMessage();
            response.responseBody = Blob.valueOf(JSON.serialize(dResponse));
            return;
        }

        // service response
        response.responseBody = Blob.valueOf(JSON.serialize(dResponse));
    }

    public class dispatcherResponse {
        public Boolean result;
        public String error;
        public Integer numberProcessed;
        public Boolean completed; // consumed all records in band
        public Cursor cursor = new Cursor();

        public void init(Cursor request) {
            cursor = request;
            result = true;
            completed = false;
            numberProcessed = 0;
            error = '';
        }
    }
    public class Cursor {
        public Integer band; // same as shard/subshard in TL
        public Integer partitionBits; // Not yet used (currently 3 bits - 8 bands)
        public Integer chunkBits; // Not yet used (currently ~14.90839 bits - 30752 recs/chunk)
        public Integer batchSize; // Max number of records to pull
        public Boolean sparse; // Will be true if last chunk in band was empty
        public String offset; // Last Id queried (not necessarily processed)
        public String url;
        public String session;
    }

}