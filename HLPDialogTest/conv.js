/*******************************************************************************
 * Copyright (c) 2014, 2021  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

let elevator = new RegExp("elevator|Elevator")
let subway = new RegExp("subway|station|Subway|Station")
let dotavelka = new RegExp("cafe|eat|Cafe|Eat|Café|café")

let trl = new RegExp("research|Tokyo|Research")
let vm10 = new RegExp("10")
let vm11 = new RegExp("11")
let entrance = new RegExp("entrance|Entrance")

function getResponse(request) {
    let text = request.input.text

    var speak = "Sorry, I couldn't catch you."
    var navi = false
    var dest_info = null
    var find_info = null
    
    if (text) {
        if (elevator.test(text)) {
            speak = "OK, going to the elevator."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1474876589541",
            }
        }else if (subway.test(text)){
            speak = "OK, going to the subway station."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1599633337007"
            }
        }else if (dotavelka.test(text)){
            speak = "OK, going to Do Tabelka."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1475144465320",
            }
        }else if (trl.test(text)){
            speak = "OK, going to TRL."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1589780736215"
            }
        }else if (vm10.test(text)){
            speak = "OK, going to vending machine of 10th floor."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1589781790959"
            }
        }else if (vm11.test(text)){
            speak = "OK, going to vending machine of 11th floor."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1589781245452"
            }
        }else if (entrance.test(text)){
            speak = "OK, going to the entrance."
	    navi = true
            dest_info = {
                "nodes": "EDITOR_node_1599730474821"
            }
        }
    }else{
        speak = "Where are you going?"
    }
    return {
        "output": {
            "log_messages":[],
            "text": [speak]
        },
        "intents":[],
        "entities":[],
        "context":{
            "navi": navi,
            "dest_info": dest_info,
            "system":{
                "dialog_request_counter":0
            }
        }
    }
}
