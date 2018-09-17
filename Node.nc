/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface List<pack> as PacketsList;   //Create a list for all the packets
}

implementation{

   unit16_t sequenceCounter;            //Create a counter for sequence number and initialize at 0
   pack sendPackage;


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   bool findPack(pack *Package);            //find already listed packages
   void pushPack(pack Package);          //Create function to push package

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){

         pack* myMsg=(pack*) payload;       //Create pack pointer from myMsg to payload
         if ((myMsg->TTL = 0) || (findPack(myMsg))) {
          //drop the packet
         }
          else if(myMsg->protocol == 0 && (myMsg->dest == TOS_NODE_ID))   //Check protocol validity & destination ID
         {
         dbg(GENERAL_CHANNEL, "Destination achieved. Package Payload: %s\n", myMsg->payload);    //Output Message

         makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, sequenceCounter, (unit8_t *) myMsg->payload, sizeof(myMsg->payload));         //Create pack containing all necessary information

         sequence counter++;       //Increment sequence for new pack
         pushPack(sendPackage);    //Send our new pack
         call Sender.send(sendPackage, AM_BROADCAST_ADDR);       //Check broadcaster node address

        }
        else if(myMsg->protocol == 1 && (myMsg->dest == TOS_NODE_ID))       //Check protocol and node ID
        {
           dbg(GENERAL_CHANNEL, "Reply delivered from: %d!\n", myMsg->src);     //Print message
        }
        else
        {
           makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (unit8_t *) myMsg->payload, sizeof(myMsg->payload));      //Create pack containing all needed information

           dbg(GENERAL_CHANNEL, "Recieved from %d, intended for %d, TTL: $d. Rebroadcasting\n", myMsg->src, myMsg->dest, myMsg->TTL);           //Output Message
           pushPack(sendPackage);     //Send out new pack
           call Sender.send(sendPackage, AM_BROADCAST_ADDR);        //Check broadcaster node address
         }
            return msg;
    }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   void pushPack(pack Package)
   {
        if(call PacketList.isfull())
        {
            call PacketList.popfront();
        }
    }

   bool findPack(pack *Package)         //iterates through PacketList and checks for repeats
   {

		uint16_t size = call PacketList.size();
		uint16_t i = 0;
		pack Match;
		for (i = 0; i < size; i++) {
			Match = call PacketList.get(i);         //check sequence numbers and source informations
			if((Match.src == Package->src) && (Match.dest == Package->dest) && (Match.seq == Package->seq)) {
				return TRUE;
			}
		}
		return FALSE;

  }
}
