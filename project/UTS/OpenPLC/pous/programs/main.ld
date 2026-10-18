PROGRAM main
  VAR
    COLOR_SENSOR1 : INT AT %QW1;
    COLOR_SENSOR2 : INT AT %QW2;
    IS_RED : BOOL;
    DO_Conveyor : BOOL AT %QX0.0;
    PUSHER : BOOL AT %QX0.1;
  END_VAR

{
  "name": "main",
  "rungs": [
    {
      "id": "rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd",
      "comment": "",
      "defaultBounds": [
        300,
        100
      ],
      "reactFlowViewport": [
        323,
        120
      ],
      "nodes": [
        {
          "id": "left-rail-rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd",
          "type": "powerRail",
          "position": {
            "x": 0,
            "y": 30
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 3,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "left-rail",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "right": -3
                }
              }
            ],
            "inputHandles": [],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 3,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "left-rail",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "right": -3
                }
              }
            ],
            "outputConnector": {
              "glbPosition": {
                "x": 3,
                "y": 50
              },
              "relPosition": {
                "x": 3,
                "y": 20
              },
              "id": "left-rail",
              "position": "right",
              "type": "source",
              "isConnectable": false,
              "style": {
                "top": 20,
                "right": -3
              }
            },
            "numericId": "9590626",
            "variant": "left",
            "variable": {
              "name": ""
            },
            "executionOrder": 0,
            "draggable": false,
            "selectable": false,
            "deletable": false
          },
          "width": 3,
          "height": 40,
          "measured": {
            "width": 3,
            "height": 40
          },
          "draggable": false,
          "selectable": false,
          "selected": false,
          "dragging": false
        },
        {
          "id": "CONTACT_f31261be-2f26-43f6-8ccd-b46cfb1e4567",
          "type": "contact",
          "position": {
            "x": 68,
            "y": 38
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 68,
                  "y": 50
                },
                "relPosition": {
                  "x": 0,
                  "y": 12
                },
                "id": "input",
                "position": "left",
                "isConnectable": false,
                "type": "target",
                "style": {
                  "left": -3
                }
              },
              {
                "glbPosition": {
                  "x": 92,
                  "y": 50
                },
                "relPosition": {
                  "x": 24,
                  "y": 12
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source",
                "style": {
                  "right": -3
                }
              }
            ],
            "variant": "default",
            "inputHandles": [
              {
                "glbPosition": {
                  "x": 68,
                  "y": 50
                },
                "relPosition": {
                  "x": 0,
                  "y": 12
                },
                "id": "input",
                "position": "left",
                "isConnectable": false,
                "type": "target",
                "style": {
                  "left": -3
                }
              }
            ],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 92,
                  "y": 50
                },
                "relPosition": {
                  "x": 24,
                  "y": 12
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source",
                "style": {
                  "right": -3
                }
              }
            ],
            "inputConnector": {
              "glbPosition": {
                "x": 68,
                "y": 50
              },
              "relPosition": {
                "x": 0,
                "y": 12
              },
              "id": "input",
              "position": "left",
              "isConnectable": false,
              "type": "target",
              "style": {
                "left": -3
              }
            },
            "outputConnector": {
              "glbPosition": {
                "x": 92,
                "y": 50
              },
              "relPosition": {
                "x": 24,
                "y": 12
              },
              "id": "output",
              "position": "right",
              "isConnectable": false,
              "type": "source",
              "style": {
                "right": -3
              }
            },
            "numericId": "4705589",
            "variable": {
              "id": "6033a7ea-2b08-4b0b-a41f-adb6de0a3b69",
              "name": "TEST",
              "type": {
                "definition": "base-type",
                "value": "BOOL"
              },
              "class": "local",
              "location": "",
              "documentation": "",
              "debug": false
            },
            "executionOrder": 0,
            "draggable": true,
            "selectable": true,
            "deletable": true
          },
          "width": 24,
          "height": 24,
          "measured": {
            "width": 24,
            "height": 24
          },
          "draggable": true,
          "selectable": true,
          "selected": false,
          "dragging": false
        },
        {
          "id": "COIL_d22615d8-9e2e-429d-9d7f-9d380548608b",
          "type": "coil",
          "position": {
            "x": 182,
            "y": 38
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 182,
                  "y": 50
                },
                "relPosition": {
                  "x": 0,
                  "y": 12
                },
                "id": "input",
                "position": "left",
                "isConnectable": false,
                "type": "target",
                "style": {
                  "left": -3
                }
              },
              {
                "glbPosition": {
                  "x": 210,
                  "y": 50
                },
                "relPosition": {
                  "x": 28,
                  "y": 12
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source",
                "style": {
                  "right": -3
                }
              }
            ],
            "variant": "default",
            "inputHandles": [
              {
                "glbPosition": {
                  "x": 182,
                  "y": 50
                },
                "relPosition": {
                  "x": 0,
                  "y": 12
                },
                "id": "input",
                "position": "left",
                "isConnectable": false,
                "type": "target",
                "style": {
                  "left": -3
                }
              }
            ],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 210,
                  "y": 50
                },
                "relPosition": {
                  "x": 28,
                  "y": 12
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source",
                "style": {
                  "right": -3
                }
              }
            ],
            "inputConnector": {
              "glbPosition": {
                "x": 182,
                "y": 50
              },
              "relPosition": {
                "x": 0,
                "y": 12
              },
              "id": "input",
              "position": "left",
              "isConnectable": false,
              "type": "target",
              "style": {
                "left": -3
              }
            },
            "outputConnector": {
              "glbPosition": {
                "x": 210,
                "y": 50
              },
              "relPosition": {
                "x": 28,
                "y": 12
              },
              "id": "output",
              "position": "right",
              "isConnectable": false,
              "type": "source",
              "style": {
                "right": -3
              }
            },
            "numericId": "9434078",
            "variable": {
              "id": "",
              "name": "DO_Conveyor",
              "type": {
                "definition": "base-type",
                "value": "BOOL"
              },
              "class": "local",
              "location": "",
              "documentation": "",
              "debug": false
            },
            "executionOrder": 0,
            "draggable": true,
            "selectable": true,
            "deletable": true
          },
          "width": 28,
          "height": 24,
          "measured": {
            "width": 28,
            "height": 24
          },
          "draggable": true,
          "selectable": true,
          "selected": false,
          "dragging": false
        },
        {
          "id": "right-rail-rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd",
          "type": "powerRail",
          "position": {
            "x": 320,
            "y": 30
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 297,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "right-rail",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "left": -3
                },
                "x": 320
              }
            ],
            "inputHandles": [
              {
                "glbPosition": {
                  "x": 297,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "right-rail",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "left": -3
                }
              }
            ],
            "outputHandles": [],
            "inputConnector": {
              "glbPosition": {
                "x": 297,
                "y": 50
              },
              "relPosition": {
                "x": 3,
                "y": 20
              },
              "id": "right-rail",
              "position": "left",
              "type": "target",
              "isConnectable": false,
              "style": {
                "top": 20,
                "left": -3
              }
            },
            "numericId": "6127408",
            "variant": "right",
            "variable": {
              "name": ""
            },
            "executionOrder": 0,
            "draggable": false,
            "selectable": false,
            "deletable": false
          },
          "width": 3,
          "height": 40,
          "measured": {
            "width": 3,
            "height": 40
          },
          "draggable": false,
          "selectable": false,
          "selected": false,
          "dragging": false
        }
      ],
      "edges": [
        {
          "id": "e_COIL_d22615d8-9e2e-429d-9d7f-9d380548608b_right-rail-rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd__output_right-rail",
          "source": "COIL_d22615d8-9e2e-429d-9d7f-9d380548608b",
          "target": "right-rail-rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd",
          "sourceHandle": "output",
          "targetHandle": "right-rail"
        },
        {
          "id": "e_left-rail-rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd_CONTACT_f31261be-2f26-43f6-8ccd-b46cfb1e4567__left-rail_input",
          "source": "left-rail-rung_main_0f469fc9-51fb-42a0-ba3b-f965274ae4bd",
          "target": "CONTACT_f31261be-2f26-43f6-8ccd-b46cfb1e4567",
          "sourceHandle": "left-rail",
          "targetHandle": "input"
        },
        {
          "id": "e_CONTACT_f31261be-2f26-43f6-8ccd-b46cfb1e4567_COIL_d22615d8-9e2e-429d-9d7f-9d380548608b__output_input",
          "source": "CONTACT_f31261be-2f26-43f6-8ccd-b46cfb1e4567",
          "target": "COIL_d22615d8-9e2e-429d-9d7f-9d380548608b",
          "sourceHandle": "output",
          "targetHandle": "input"
        }
      ],
      "selectedNodes": [],
      "handleBranches": []
    },
    {
      "id": "rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7",
      "comment": "",
      "defaultBounds": [
        300,
        100
      ],
      "reactFlowViewport": [
        539,
        214
      ],
      "nodes": [
        {
          "id": "left-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7",
          "type": "powerRail",
          "position": {
            "x": 0,
            "y": 30
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 3,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "left-rail",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "right": -3
                }
              }
            ],
            "inputHandles": [],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 3,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "left-rail",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "right": -3
                }
              }
            ],
            "outputConnector": {
              "glbPosition": {
                "x": 3,
                "y": 50
              },
              "relPosition": {
                "x": 3,
                "y": 20
              },
              "id": "left-rail",
              "position": "right",
              "type": "source",
              "isConnectable": false,
              "style": {
                "top": 20,
                "right": -3
              }
            },
            "numericId": "9927049",
            "variant": "left",
            "variable": {
              "name": ""
            },
            "executionOrder": 0,
            "draggable": false,
            "selectable": false,
            "deletable": false
          },
          "width": 3,
          "height": 40,
          "measured": {
            "width": 3,
            "height": 40
          },
          "draggable": false,
          "selectable": false,
          "selected": false,
          "dragging": false
        },
        {
          "id": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "type": "block",
          "position": {
            "x": 143,
            "y": 14
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 143,
                  "y": 50
                },
                "relPosition": {
                  "x": 0,
                  "y": 36
                },
                "id": "EN",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 36,
                  "left": 0
                }
              },
              {
                "glbPosition": {
                  "x": 143,
                  "y": 130
                },
                "relPosition": {
                  "x": 0,
                  "y": 116
                },
                "id": "IN1",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 116,
                  "left": 0
                }
              },
              {
                "glbPosition": {
                  "x": 143,
                  "y": 170
                },
                "relPosition": {
                  "x": 0,
                  "y": 156
                },
                "id": "IN2",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 156,
                  "left": 0
                }
              },
              {
                "glbPosition": {
                  "x": 233,
                  "y": 50
                },
                "relPosition": {
                  "x": 90,
                  "y": 36
                },
                "id": "ENO",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 36,
                  "right": 0
                }
              },
              {
                "glbPosition": {
                  "x": 233,
                  "y": 130
                },
                "relPosition": {
                  "x": 90,
                  "y": 116
                },
                "id": "OUT",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 116,
                  "right": 0
                }
              }
            ],
            "inputHandles": [
              {
                "glbPosition": {
                  "x": 143,
                  "y": 50
                },
                "relPosition": {
                  "x": 0,
                  "y": 36
                },
                "id": "EN",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 36,
                  "left": 0
                }
              },
              {
                "glbPosition": {
                  "x": 143,
                  "y": 130
                },
                "relPosition": {
                  "x": 0,
                  "y": 116
                },
                "id": "IN1",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 116,
                  "left": 0
                }
              },
              {
                "glbPosition": {
                  "x": 143,
                  "y": 170
                },
                "relPosition": {
                  "x": 0,
                  "y": 156
                },
                "id": "IN2",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 156,
                  "left": 0
                }
              }
            ],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 233,
                  "y": 50
                },
                "relPosition": {
                  "x": 90,
                  "y": 36
                },
                "id": "ENO",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 36,
                  "right": 0
                }
              },
              {
                "glbPosition": {
                  "x": 233,
                  "y": 130
                },
                "relPosition": {
                  "x": 90,
                  "y": 116
                },
                "id": "OUT",
                "position": "right",
                "type": "source",
                "isConnectable": false,
                "style": {
                  "top": 116,
                  "right": 0
                }
              }
            ],
            "inputConnector": {
              "glbPosition": {
                "x": 143,
                "y": 50
              },
              "relPosition": {
                "x": 0,
                "y": 36
              },
              "id": "EN",
              "position": "left",
              "type": "target",
              "isConnectable": false,
              "style": {
                "top": 36,
                "left": 0
              }
            },
            "outputConnector": {
              "glbPosition": {
                "x": 233,
                "y": 50
              },
              "relPosition": {
                "x": 90,
                "y": 36
              },
              "id": "ENO",
              "position": "right",
              "type": "source",
              "isConnectable": false,
              "style": {
                "top": 36,
                "right": 0
              }
            },
            "numericId": "6079822",
            "variant": {
              "name": "EQ",
              "type": "function",
              "language": "st",
              "variables": [
                {
                  "name": "EN",
                  "class": "input",
                  "type": {
                    "definition": "generic-type",
                    "value": "BOOL"
                  }
                },
                {
                  "name": "ENO",
                  "class": "output",
                  "type": {
                    "definition": "generic-type",
                    "value": "BOOL"
                  }
                },
                {
                  "name": "OUT",
                  "class": "output",
                  "type": {
                    "definition": "base-type",
                    "value": "BOOL"
                  }
                },
                {
                  "name": "IN1",
                  "class": "input",
                  "type": {
                    "definition": "generic-type",
                    "value": "ANY_ELEMENTARY"
                  }
                },
                {
                  "name": "IN2",
                  "class": "input",
                  "type": {
                    "definition": "generic-type",
                    "value": "ANY_ELEMENTARY"
                  }
                }
              ],
              "body": "",
              "documentation": "",
              "extensible": true,
              "category": "Comparison"
            },
            "variable": {
              "name": ""
            },
            "executionOrder": 0,
            "executionControl": true,
            "lockExecutionControl": false,
            "connectedVariables": [
              {
                "handleId": "IN1",
                "type": "input",
                "variable": {
                  "id": "",
                  "name": "COLOR_SENSOR1",
                  "type": {
                    "definition": "base-type",
                    "value": "INT"
                  },
                  "class": "local",
                  "location": "",
                  "documentation": "",
                  "debug": false
                }
              },
              {
                "handleId": "IN2",
                "type": "input",
                "variable": {
                  "name": "1"
                }
              }
            ],
            "draggable": true,
            "selectable": true,
            "deletable": true
          },
          "width": 90,
          "height": 180,
          "measured": {
            "width": 90,
            "height": 180
          },
          "draggable": true,
          "selectable": true,
          "selected": false,
          "dragging": false
        },
        {
          "id": "COIL_68bbb02c-2db7-4b37-b6af-a1b57344bce9",
          "type": "coil",
          "position": {
            "x": 398,
            "y": 118
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 398,
                  "y": 130
                },
                "relPosition": {
                  "x": 0,
                  "y": 12
                },
                "id": "input",
                "position": "left",
                "isConnectable": false,
                "type": "target",
                "style": {
                  "left": -3
                }
              },
              {
                "glbPosition": {
                  "x": 426,
                  "y": 130
                },
                "relPosition": {
                  "x": 28,
                  "y": 12
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source",
                "style": {
                  "right": -3
                }
              }
            ],
            "variant": "default",
            "inputHandles": [
              {
                "glbPosition": {
                  "x": 398,
                  "y": 130
                },
                "relPosition": {
                  "x": 0,
                  "y": 12
                },
                "id": "input",
                "position": "left",
                "isConnectable": false,
                "type": "target",
                "style": {
                  "left": -3
                }
              }
            ],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 426,
                  "y": 130
                },
                "relPosition": {
                  "x": 28,
                  "y": 12
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source",
                "style": {
                  "right": -3
                }
              }
            ],
            "inputConnector": {
              "glbPosition": {
                "x": 398,
                "y": 130
              },
              "relPosition": {
                "x": 0,
                "y": 12
              },
              "id": "input",
              "position": "left",
              "isConnectable": false,
              "type": "target",
              "style": {
                "left": -3
              }
            },
            "outputConnector": {
              "glbPosition": {
                "x": 426,
                "y": 130
              },
              "relPosition": {
                "x": 28,
                "y": 12
              },
              "id": "output",
              "position": "right",
              "isConnectable": false,
              "type": "source",
              "style": {
                "right": -3
              }
            },
            "numericId": "6592215",
            "variable": {
              "id": "",
              "name": "IS_RED",
              "type": {
                "definition": "base-type",
                "value": "BOOL"
              },
              "class": "local",
              "location": "",
              "documentation": "",
              "debug": false
            },
            "executionOrder": 0,
            "draggable": true,
            "selectable": true,
            "deletable": true,
            "branchContext": {
              "blockId": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
              "handleId": "OUT",
              "direction": "output"
            }
          },
          "width": 28,
          "height": 24,
          "measured": {
            "width": 28,
            "height": 24
          },
          "draggable": true,
          "selectable": true,
          "selected": false,
          "dragging": false
        },
        {
          "id": "right-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7",
          "type": "powerRail",
          "position": {
            "x": 536,
            "y": 30
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 297,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "right-rail",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "left": -3
                },
                "x": 536
              },
              {
                "glbPosition": {
                  "x": 297,
                  "y": 130
                },
                "relPosition": {
                  "x": 3,
                  "y": 100
                },
                "id": "branch_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3_OUT",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 100,
                  "left": -3
                },
                "x": 536
              }
            ],
            "inputHandles": [
              {
                "glbPosition": {
                  "x": 297,
                  "y": 50
                },
                "relPosition": {
                  "x": 3,
                  "y": 20
                },
                "id": "right-rail",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 20,
                  "left": -3
                },
                "x": 536
              },
              {
                "glbPosition": {
                  "x": 297,
                  "y": 130
                },
                "relPosition": {
                  "x": 3,
                  "y": 100
                },
                "id": "branch_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3_OUT",
                "position": "left",
                "type": "target",
                "isConnectable": false,
                "style": {
                  "top": 100,
                  "left": -3
                },
                "x": 536
              }
            ],
            "outputHandles": [],
            "inputConnector": {
              "glbPosition": {
                "x": 297,
                "y": 50
              },
              "relPosition": {
                "x": 3,
                "y": 20
              },
              "id": "right-rail",
              "position": "left",
              "type": "target",
              "isConnectable": false,
              "style": {
                "top": 20,
                "left": -3
              }
            },
            "numericId": "9276578",
            "variant": "right",
            "variable": {
              "name": ""
            },
            "executionOrder": 0,
            "draggable": false,
            "selectable": false,
            "deletable": false
          },
          "width": 3,
          "height": 40,
          "measured": {
            "width": 3,
            "height": 40
          },
          "draggable": false,
          "selectable": false,
          "selected": false,
          "dragging": false
        },
        {
          "id": "VARIABLE_47369ed6-b00a-4068-9dd6-c02402d4edaf",
          "type": "variable",
          "position": {
            "x": 33,
            "y": 114
          },
          "width": 80,
          "height": 32,
          "measured": {
            "width": 80,
            "height": 32
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 193,
                  "y": 130
                },
                "relPosition": {
                  "x": 80,
                  "y": 16
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source"
              }
            ],
            "inputHandles": [],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 193,
                  "y": 130
                },
                "relPosition": {
                  "x": 80,
                  "y": 16
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source"
              }
            ],
            "outputConnector": {
              "glbPosition": {
                "x": 193,
                "y": 130
              },
              "relPosition": {
                "x": 80,
                "y": 16
              },
              "id": "output",
              "position": "right",
              "isConnectable": false,
              "type": "source"
            },
            "numericId": "3992775",
            "variable": {
              "id": "",
              "name": "COLOR_SENSOR1",
              "type": {
                "definition": "base-type",
                "value": "INT"
              },
              "class": "local",
              "location": "",
              "documentation": "",
              "debug": false
            },
            "executionOrder": 0,
            "variant": "input",
            "block": {
              "id": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
              "handleId": "IN1",
              "variableType": {
                "name": "IN1",
                "class": "input",
                "type": {
                  "definition": "generic-type",
                  "value": "ANY_ELEMENTARY"
                }
              }
            },
            "draggable": false,
            "selectable": true,
            "deletable": false
          },
          "deletable": false,
          "selectable": true,
          "draggable": false,
          "selected": false,
          "dragging": false
        },
        {
          "id": "VARIABLE_4a4d0a0c-5fa2-4f54-8486-4f3574524440",
          "type": "variable",
          "position": {
            "x": 33,
            "y": 154
          },
          "width": 80,
          "height": 32,
          "measured": {
            "width": 80,
            "height": 32
          },
          "data": {
            "handles": [
              {
                "glbPosition": {
                  "x": 193,
                  "y": 170
                },
                "relPosition": {
                  "x": 80,
                  "y": 16
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source"
              }
            ],
            "inputHandles": [],
            "outputHandles": [
              {
                "glbPosition": {
                  "x": 193,
                  "y": 170
                },
                "relPosition": {
                  "x": 80,
                  "y": 16
                },
                "id": "output",
                "position": "right",
                "isConnectable": false,
                "type": "source"
              }
            ],
            "outputConnector": {
              "glbPosition": {
                "x": 193,
                "y": 170
              },
              "relPosition": {
                "x": 80,
                "y": 16
              },
              "id": "output",
              "position": "right",
              "isConnectable": false,
              "type": "source"
            },
            "numericId": "637717",
            "variable": {
              "name": "1"
            },
            "executionOrder": 0,
            "variant": "input",
            "block": {
              "id": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
              "handleId": "IN2",
              "variableType": {
                "name": "IN2",
                "class": "input",
                "type": {
                  "definition": "generic-type",
                  "value": "ANY_ELEMENTARY"
                }
              }
            },
            "draggable": false,
            "selectable": true,
            "deletable": false
          },
          "deletable": false,
          "selectable": true,
          "draggable": false,
          "selected": false,
          "dragging": false
        }
      ],
      "edges": [
        {
          "id": "e_left-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3__left-rail_IN1",
          "source": "left-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7",
          "target": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "sourceHandle": "left-rail",
          "targetHandle": "EN"
        },
        {
          "id": "e_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3_right-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7__ENO_right-rail",
          "source": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "target": "right-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7",
          "sourceHandle": "ENO",
          "targetHandle": "right-rail"
        },
        {
          "id": "e_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3_COIL_68bbb02c-2db7-4b37-b6af-a1b57344bce9__OUT_input",
          "source": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "target": "COIL_68bbb02c-2db7-4b37-b6af-a1b57344bce9",
          "sourceHandle": "OUT",
          "targetHandle": "input"
        },
        {
          "id": "e_COIL_68bbb02c-2db7-4b37-b6af-a1b57344bce9_right-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7__output_branch_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3_OUT",
          "source": "COIL_68bbb02c-2db7-4b37-b6af-a1b57344bce9",
          "target": "right-rail-rung_main_ac640fe8-fe08-4ec0-a261-abb8c0145da7",
          "sourceHandle": "output",
          "targetHandle": "branch_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3_OUT"
        },
        {
          "id": "e_VARIABLE_47369ed6-b00a-4068-9dd6-c02402d4edaf_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3__output_IN1",
          "source": "VARIABLE_47369ed6-b00a-4068-9dd6-c02402d4edaf",
          "target": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "sourceHandle": "output",
          "targetHandle": "IN1"
        },
        {
          "id": "e_VARIABLE_4a4d0a0c-5fa2-4f54-8486-4f3574524440_BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3__output_IN2",
          "source": "VARIABLE_4a4d0a0c-5fa2-4f54-8486-4f3574524440",
          "target": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "sourceHandle": "output",
          "targetHandle": "IN2"
        }
      ],
      "selectedNodes": [],
      "handleBranches": [
        {
          "blockId": "BLOCK_6231f23e-aecb-469e-84eb-9c79c25e86e3",
          "handleId": "OUT",
          "direction": "output",
          "nodeIds": [
            "COIL_68bbb02c-2db7-4b37-b6af-a1b57344bce9"
          ]
        }
      ]
    }
  ]
}
END_PROGRAM