/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker

Item {
    id: itemMultiGrid

    anchors {
        top: parent.top
    }

    width: parent.width

    implicitHeight: itemColumn.implicitHeight

    signal keyNavLeft(int subGridIndex)
    signal keyNavRight(int subGridIndex)
    signal keyNavUp()
    signal keyNavDown()

    property bool grabFocus: false

    property alias model: repeater.model
    property alias count: repeater.count
    property alias flickableItem: flickable

    function subGridAt(index) {
        return repeater.itemAt(index).itemGrid;
    }

    function tryActivate(row, col) { // FIXME TODO: Cleanup messy algo.
        if (flickable.contentY > 0) {
            row = 0;
        }

        var target = null;
        var rows = 0;

        for (var i = 0; i < repeater.count; i++) {
            var grid = subGridAt(i);

            if (rows <= row) {
                target = grid;
                rows += grid.lastRow() + 2; // Header counts as one.
            } else {
                break;
            }
        }

        if (target) {
            rows -= (target.lastRow() + 2);
            target.tryActivate(row - rows, col);
        }
    }

    onFocusChanged: {
        if (!focus) {
            for (var i = 0; i < repeater.count; i++) {
                subGridAt(i).focus = false;
            }
        }
    }

    Flickable {
        id: flickable

        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: itemColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        
        Column {
            id: itemColumn

            width: itemMultiGrid.width

            Repeater {
                id: repeater

                delegate: Item {
                    width: itemColumn.width
                    height: {
                        var gridHeight = 0;
                        if (gridView.count > 0) {
                            var columns = Math.floor(itemColumn.width / cellSize);
                            var rows = Math.ceil(gridView.count / columns);
                            gridHeight = rows * cellSize;
                        }
                        return headerHeight + gridHeight + (index == repeater.count - 1 ? Kirigami.Units.largeSpacing : footerHeight);
                    }

                    property int headerHeight: (gridViewLabel.height
                        + gridViewLabelUnderline.height + Kirigami.Units.gridUnit)
                    property int footerHeight: (Math.ceil(headerHeight / cellSize) * cellSize) - headerHeight

                    property Item itemGrid: gridView

                    Kirigami.Heading {
                        id: gridViewLabel

                        anchors.top: parent.top

                        x: Kirigami.Units.smallSpacing
                        width: parent.width - x
                        height: dummyHeading.height

                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        opacity: 1.0

                        color: "white" // FIXME TODO: Respect theming?

                        level: 1

                        text: repeater.model.modelForRow(index).description
                        textFormat: Text.PlainText
                    }

                    KSvg.SvgItem {
                        id: gridViewLabelUnderline

                        anchors.top: gridViewLabel.bottom

                        width: parent.width
                        height: lineSvg.horLineHeight

                        svg: lineSvg
                        elementId: "horizontal-line"
                    }

                    MouseArea {
                        width: parent.width
                        height: parent.height

                        onClicked: root.toggle()
                    }

                    ItemGridView {
                        id: gridView

                        anchors {
                            top: gridViewLabelUnderline.bottom
                            topMargin: Kirigami.Units.gridUnit
                        }

                        width: parent.width
                        height: {
                            if (count === 0) return 0;
                            var columns = Math.floor(parent.width / cellSize);
                            var rows = Math.ceil(count / columns);
                            return rows * cellSize;
                        }

                        cellWidth: cellSize
                        cellHeight: cellSize
                        iconSize: root.iconSize

                        verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff

                        model: repeater.model.modelForRow(index)

                        onFocusChanged: {
                            if (focus) {
                                itemMultiGrid.focus = true;
                            }
                        }

                        onCountChanged: {
                            if (itemMultiGrid.grabFocus && index == 0 && count > 0) {
                                currentIndex = 0;
                                focus = true;
                            }
                        }

                        onCurrentItemChanged: {
                            if (!currentItem) {
                                return;
                            }

                            if (index == 0 && currentRow() === 0) {
                                flickable.contentY = 0;
                                return;
                            }

                            var y = currentItem.y;
                            y = contentItem.mapToItem(flickable.contentItem, 0, y).y;

                            if (y < flickable.contentY) {
                                flickable.contentY = y;
                            } else {
                                y += cellSize;
                                y -= flickable.contentY;
                                y -= itemMultiGrid.height;

                                if (y > 0) {
                                    flickable.contentY += y;
                                }
                            }
                        }

                        onKeyNavLeft: {
                            itemMultiGrid.keyNavLeft(index);
                        }

                        onKeyNavRight: {
                            itemMultiGrid.keyNavRight(index);
                        }

                        onKeyNavUp: {
                            if (index > 0) {
                                var prevGrid = subGridAt(index - 1);
                                prevGrid.tryActivate(prevGrid.lastRow(), currentCol());
                            } else {
                                itemMultiGrid.keyNavUp();
                            }
                        }

                        onKeyNavDown: {
                            if (index < repeater.count - 1) {
                                subGridAt(index + 1).tryActivate(0, currentCol());
                            } else {
                                itemMultiGrid.keyNavDown();
                            }
                        }
                    }

                    // HACK: Steal wheel events from the nested grid view and forward them to
                    // the ScrollView's internal WheelArea.
                    Kicker.WheelInterceptor {
                        anchors.fill: gridView
                        z: 1

                        destination: findWheelArea(itemMultiGrid)
                    }
                }
            }
        }
    }
}
